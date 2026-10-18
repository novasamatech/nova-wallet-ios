import Foundation
import Foundation_iOS
import Operation_iOS

final class SubtensorSubnetDetailsInteractor: AnyProviderAutoCleaning, SubtensorLoadDelivering {
    weak var presenter: SubtensorSubnetDetailsInteractorOutputProtocol?

    let subnet: SubtensorSubnetRef
    let chainAsset: ChainAsset
    let priceHistoryOperationFactory: SubtensorPriceHistoryOperationFactoryProtocol?
    let parametersOperationFactory: SubtensorSubnetParametersOperationFactoryProtocol
    let presetOperationFactory: SubtensorValidatorPresetOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let earnSettings: SubtensorEarnSettingsProtocol
    let positionsSyncService: SubtensorPositionsSyncServiceProtocol?
    let applicationHandler: ApplicationHandlerProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
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
        state: SubtensorSharedStateProtocol,
        parametersOperationFactory: SubtensorSubnetParametersOperationFactoryProtocol,
        applicationHandler: ApplicationHandlerProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.subnet = subnet
        chainAsset = state.stakingOption.chainAsset
        priceHistoryOperationFactory = state.earnServices.priceHistoryOperationFactory
        self.parametersOperationFactory = parametersOperationFactory
        presetOperationFactory = state.earnServices.validatorPresetOperationFactory
        yieldOperationFactory = state.earnServices.yieldOperationFactory
        subnetLogosProvider = state.earnServices.subnetLogosProvider
        earnSettings = state.earnServices.earnSettings
        positionsSyncService = state.positionsSyncService
        self.applicationHandler = applicationHandler
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
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

    func provideFavorite() {
        presenter?.didReceive(isFavorite: earnSettings.favouriteSubnets.contains(subnet))
    }

    func loadYields() {
        let yieldOperationFactory = yieldOperationFactory
        let netuid = subnet.netuid

        load(
            yieldOperationFactory.createAlphaYieldsWrapper(for: netuid),
            cached: { yieldOperationFactory.cachedFreshAlphaYields(for: netuid) },
            in: yieldsCallStore,
            label: "subnet yields",
            deliver: { [weak self] in
                self?.presenter?.didReceiveYields($0)
            }
        )
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

extension SubtensorSubnetDetailsInteractor: SubtensorSubnetDetailsInteractorInputProtocol {
    func setup() {
        provideFavorite()
        subscribeTaoPrice(currency: selectedCurrency)
        subscribePositions()

        loadYields()
        loadSubnetLogos()

        applicationHandler.delegate = self
    }

    func loadParameters() {
        parametersCallStore.cancel()

        load(
            parametersOperationFactory.createWrapper(for: subnet),
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

        let wrapper = priceHistoryOperationFactory?.createHistoryWrapper(
            for: subnet,
            period: period,
            currency: selectedCurrency
        ) ?? .createWithResult(nil)

        load(wrapper, in: historyCallStore, label: "subnet price history") { [weak self] in
            self?.presenter?.didReceiveHistory($0, for: period)
        } fail: { [weak self] in
            self?.presenter?.didFailHistory(for: period)
        }
    }

    func toggleFavorite() {
        earnSettings.favouriteSubnets.formSymmetricDifference([subnet])
        provideFavorite()
    }

    func presetValidator(existingHotkey: AccountId?) {
        presetCallStore.cancel()

        load(
            presetOperationFactory.createListedPresetWrapper(for: subnet, existingHotkey: existingHotkey),
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

extension SubtensorSubnetDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        presenter?.didChangeCurrency()
        clear(streamableProvider: &priceProvider)
        subscribeTaoPrice(currency: selectedCurrency)
    }
}
