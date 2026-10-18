import Foundation
import Operation_iOS

final class SubtensorValidatorInfoInteractor: AnyProviderAutoCleaning, SubtensorLoadDelivering {
    weak var presenter: SubtensorValidatorInfoInteractorOutputProtocol?

    let target: SubtensorStakeTarget
    let hotkey: AccountId
    let chainAsset: ChainAsset
    let coverageFactory: SubtensorValidatorCoverageFactoryProtocol
    let directoryOperationFactory: SubtensorValidatorDirectoryOperationFactoryProtocol
    let yieldOperationFactory: SubtensorYieldOperationFactoryProtocol
    let catalogueOperationFactory: SubtensorSubnetCatalogueOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let coverageStore = CancellableCallStore()
    private let detailStore = CancellableCallStore()
    private let rateStore = CancellableCallStore()
    private let catalogueStore = CancellableCallStore()
    var priceProvider: StreamableProvider<PriceData>?

    init(
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        state: SubtensorStakingSharedStateProtocol,
        coverageFactory: SubtensorValidatorCoverageFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.target = target
        self.hotkey = hotkey
        chainAsset = state.stakingOption.chainAsset
        self.coverageFactory = coverageFactory
        directoryOperationFactory = state.earnServices.validatorDirectoryOperationFactory
        yieldOperationFactory = state.earnServices.yieldOperationFactory
        catalogueOperationFactory = state.earnServices.catalogueOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.currencyManager = currencyManager
    }

    deinit {
        coverageStore.cancel()
        detailStore.cancel()
        rateStore.cancel()
        catalogueStore.cancel()
    }
}

private extension SubtensorValidatorInfoInteractor {
    func createRateWrapper() -> CompoundOperationWrapper<Decimal?> {
        let hotkey = hotkey

        return yieldOperationFactory.createAlphaYieldsWrapper(for: target.netuid).mapped { yields in
            SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields)
        }
    }

    func loadRate() {
        rateStore.cancel()

        let yieldOperationFactory = yieldOperationFactory
        let hotkey = hotkey
        let netuid = target.netuid

        load(
            createRateWrapper(),
            cached: {
                yieldOperationFactory.cachedAlphaYields(for: netuid).value.map {
                    SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: $0)
                }
            },
            in: rateStore,
            label: "validator reward rate",
            deliver: { [weak self] in
                self?.presenter?.didReceive(annualRate: $0 ?? nil)
            }
        )
    }

    func loadAlphaPrice() {
        guard !target.isRoot else {
            presenter?.didReceive(alphaPrice: nil)
            return
        }

        catalogueStore.cancel()

        let subnet = target.subnetRef
        let catalogueOperationFactory = catalogueOperationFactory

        load(
            catalogueOperationFactory.createCatalogueWrapper(),
            cached: { catalogueOperationFactory.cachedCatalogue().value },
            in: catalogueStore,
            label: "catalogue for the validator stake",
            deliver: { [weak self] in
                self?.presenter?.didReceive(alphaPrice: $0?.subnet(for: subnet)?.freshTaoPerAlpha)
            }
        )
    }
}

extension SubtensorValidatorInfoInteractor: SubtensorValidatorInfoInteractorInputProtocol {
    func setup() {
        load(
            coverageFactory.createWrapper(for: hotkey),
            in: coverageStore,
            label: "validator coverage"
        ) { [weak self] in
            self?.presenter?.didReceive(coverage: $0 ?? nil)
        }
        loadRate()
        loadAlphaPrice()
        subscribeTaoPrice(currency: selectedCurrency)
    }

    func loadDetail() {
        detailStore.cancel()

        executeCancellable(
            wrapper: directoryOperationFactory.createDetailWrapper(for: hotkey, subnet: target.subnetRef),
            inOperationQueue: operationQueue,
            backingCallIn: detailStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(detail):
                self?.presenter?.didReceive(detail: detail)
            case let .failure(error):
                self?.logger.warning("Validator detail unavailable: \(error)")
                self?.presenter?.didFailDetail(error)
            }
        }
    }
}

extension SubtensorValidatorInfoInteractor: SubtensorTaoPriceSubscribing {
    func deliverTaoPrice(_ price: PriceData?) {
        presenter?.didReceive(price: price)
    }
}

extension SubtensorValidatorInfoInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        clear(streamableProvider: &priceProvider)
        subscribeTaoPrice(currency: selectedCurrency)
    }
}
