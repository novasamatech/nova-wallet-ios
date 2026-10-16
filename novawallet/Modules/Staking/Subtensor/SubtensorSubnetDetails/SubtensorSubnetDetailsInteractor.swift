import Foundation
import Operation_iOS

final class SubtensorSubnetDetailsInteractor {
    weak var presenter: SubnetDetailsInteractorOutputProtocol?

    let subnet: SubtensorSubnetRef
    let chainAsset: ChainAsset
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let parametersFactory: SubnetParametersFactoryProtocol
    let presetFactory: SubtensorValidatorPresetFactoryProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var priceProvider: StreamableProvider<PriceData>?
    private let historyCallStore = CancellableCallStore()
    private let parametersCallStore = CancellableCallStore()
    private let presetCallStore = CancellableCallStore()
    private let yieldsCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()

    init(
        subnet: SubtensorSubnetRef,
        chainAsset: ChainAsset,
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        parametersFactory: SubnetParametersFactoryProtocol,
        presetFactory: SubtensorValidatorPresetFactoryProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        positionsSyncService: SubtensorPositionsSyncServiceProtocol?,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.subnet = subnet
        self.chainAsset = chainAsset
        self.priceHistoryService = priceHistoryService
        self.parametersFactory = parametersFactory
        self.presetFactory = presetFactory
        self.yieldService = yieldService
        self.subnetLogosProvider = subnetLogosProvider
        self.positionsSyncService = positionsSyncService
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.currencyManager = currencyManager
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        historyCallStore.cancel()
        parametersCallStore.cancel()
        presetCallStore.cancel()
        yieldsCallStore.cancel()
        logosCallStore.cancel()

        positionsSyncService?.remove(observer: self)
    }
}

private extension SubtensorSubnetDetailsInteractor {
    func subscribePrice() {
        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceiveTaoPrice(nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: currencyManager.selectedCurrency)
    }

    func subscribePositions() {
        guard let positionsSyncService else {
            presenter?.didReceivePositionsSyncFailed(true)
            return
        }

        positionsSyncService.add(
            observer: self,
            onState: { [weak self] state in
                self?.presenter?.didReceivePositions(state)
            },
            onFailure: { [weak self] isFailed in
                self?.presenter?.didReceivePositionsSyncFailed(isFailed)
            }
        )
    }

    func loadParameters() {
        parametersCallStore.cancel()
        executeCancellable(
            wrapper: parametersFactory.createWrapper(for: subnet),
            inOperationQueue: operationQueue,
            backingCallIn: parametersCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(parameters): self?.presenter?.didReceiveParameters(parameters)
            case let .failure(error):
                self?.logger.warning("Subtensor parameters unavailable: \(error)")
                self?.presenter?.didReceiveParameters(nil)
            }
        }
    }

    func loadYields() {
        executeCancellable(
            wrapper: yieldService.createAlphaYieldsWrapper(for: subnet.netuid),
            inOperationQueue: operationQueue,
            backingCallIn: yieldsCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yields):
                self?.presenter?.didReceiveYields(yields)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet yields unavailable: \(error)")
                self?.presenter?.didReceiveYields(nil)
            }
        }
    }

    func loadSubnetLogos() {
        executeCancellable(
            wrapper: subnetLogosProvider.createLogosWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: logosCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(logos):
                self?.presenter?.didReceiveSubnetLogos(logos)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet logos unavailable for the subnet mark: \(error)")
                self?.presenter?.didReceiveSubnetLogos(nil)
            }
        }
    }
}

extension SubtensorSubnetDetailsInteractor: SubnetDetailsInteractorInputProtocol {
    func cachedYields() -> SubtensorAlphaYields? {
        yieldService.cachedAlphaYields(for: subnet.netuid).value
    }

    func setup() {
        subscribePrice()
        subscribePositions()

        loadParameters()
        loadYields()
        loadSubnetLogos()
    }

    func loadHistory(for period: SubtensorPricePeriod) {
        historyCallStore.cancel()

        let wrapper = priceHistoryService?.createHistoryWrapper(
            for: subnet,
            period: period,
            currency: currencyManager.selectedCurrency
        ) ?? .createWithResult(nil)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: historyCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(history):
                self?.presenter?.didReceiveHistory(history, for: period)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet price history unavailable: \(error)")
                self?.presenter?.didFailHistory(for: period)
            }
        }
    }

    func presetValidator(existingHotkey: AccountId?) {
        presetCallStore.cancel()

        executeCancellable(
            wrapper: presetFactory.createPresetWrapper(for: subnet, existingHotkey: existingHotkey),
            inOperationQueue: operationQueue,
            backingCallIn: presetCallStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(validator):
                self?.presenter?.didReceivePreset(validator)
            case let .failure(error):
                self?.logger.warning("Subtensor subnet validator preset failed: \(error)")
                self?.presenter?.didReceivePreset(nil)
            }
        }
    }
}

extension SubtensorSubnetDetailsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceiveTaoPrice(price)
        case let .failure(error):
            logger.error("Subtensor subnet details price subscription failed: \(error)")
            presenter?.didReceiveTaoPrice(nil)
        }
    }
}
