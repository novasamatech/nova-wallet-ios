import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorSubnetDetailsInteractor: SubtensorLoadDelivering {
    weak var presenter: SubnetDetailsInteractorOutputProtocol?

    let subnet: SubtensorSubnetRef
    let chainAsset: ChainAsset
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let parametersFactory: SubnetParametersFactoryProtocol
    let presetFactory: SubtensorValidatorPresetFactoryProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let applicationHandler: ApplicationHandlerProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    var priceProvider: StreamableProvider<PriceData>?
    private let historyCallStore = CancellableCallStore()
    private let parametersCallStore = CancellableCallStore()
    private let presetCallStore = CancellableCallStore()
    private let yieldsCallStore = CancellableCallStore()
    private let logosCallStore = CancellableCallStore()

    init(
        subnet: SubtensorSubnetRef,
        state: SubtensorStakingSharedStateProtocol,
        parametersFactory: SubnetParametersFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.subnet = subnet
        chainAsset = state.stakingOption.chainAsset
        priceHistoryService = state.earnServices.priceHistoryService
        self.parametersFactory = parametersFactory
        presetFactory = state.earnServices.validatorPresetFactory
        yieldService = state.earnServices.yieldService
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        positionsSyncService = state.positionsSyncService
        self.applicationHandler = applicationHandler
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

    func loadYields() {
        load(
            yieldService.createAlphaYieldsWrapper(for: subnet.netuid),
            in: yieldsCallStore,
            label: "subnet yields"
        ) { [weak self] in
            self?.presenter?.didReceiveYields($0)
        }
    }

    func loadSubnetLogos() {
        load(
            subnetLogosProvider.createLogosWrapper(),
            in: logosCallStore,
            label: "subnet logos for the subnet mark"
        ) { [weak self] in
            self?.presenter?.didReceiveSubnetLogos($0)
        }
    }
}

extension SubtensorSubnetDetailsInteractor: SubnetDetailsInteractorInputProtocol {
    func cachedYields() -> SubtensorAlphaYields? {
        yieldService.cachedAlphaYields(for: subnet.netuid).value
    }

    func setup() {
        subscribeTaoPrice(currency: currencyManager.selectedCurrency)
        subscribePositions()

        loadYields()
        loadSubnetLogos()

        applicationHandler.delegate = self
    }

    func loadParameters() {
        parametersCallStore.cancel()

        load(
            parametersFactory.createWrapper(for: subnet),
            in: parametersCallStore,
            label: "parameters"
        ) { [weak self] in
            self?.presenter?.didReceiveParameters($0)
        } fail: { [weak self] in
            self?.presenter?.didFailParameters()
        }
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

        load(
            presetFactory.createListedPresetWrapper(for: subnet, existingHotkey: existingHotkey),
            in: presetCallStore,
            label: "subnet validator preset"
        ) { [weak self] in
            self?.presenter?.didReceivePreset($0)
        } fail: { [weak self] in
            self?.presenter?.didFailPreset()
        }
    }
}

extension SubtensorSubnetDetailsInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        presenter?.didBecomeActive()
    }
}

extension SubtensorSubnetDetailsInteractor: SubtensorTaoPriceSubscribing {
    func deliverTaoPrice(_ price: PriceData?) {
        presenter?.didReceiveTaoPrice(price)
    }
}
