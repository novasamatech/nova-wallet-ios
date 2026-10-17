import Foundation
import Operation_iOS

final class SubtensorValidatorInfoInteractor: AnyCancellableCleaning, SubtensorLoadDelivering {
    weak var presenter: SubtensorValInfoInteractorOutputProtocol?

    let target: SubtensorStakeTarget
    let hotkey: AccountId
    let chainAsset: ChainAsset
    let coverageFactory: ValidatorCoverageFactoryProtocol
    let directoryService: SubtensorValidatorDirectoryServiceProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private let coverageStore = CancellableCallStore()
    private let detailStore = CancellableCallStore()
    private let rateStore = CancellableCallStore()
    private let catalogueStore = CancellableCallStore()
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        target: SubtensorStakeTarget,
        hotkey: AccountId,
        chainAsset: ChainAsset,
        coverageFactory: ValidatorCoverageFactoryProtocol,
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.target = target
        self.hotkey = hotkey
        self.chainAsset = chainAsset
        self.coverageFactory = coverageFactory
        self.directoryService = directoryService
        self.yieldService = yieldService
        self.catalogueService = catalogueService
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

        return yieldService.createAlphaYieldsWrapper(for: target.netuid).mapped { yields in
            SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields)
        }
    }

    func loadRate() {
        rateStore.cancel()

        load(createRateWrapper(), in: rateStore, label: "validator reward rate") { [weak self] in
            self?.presenter?.didReceive(annualRate: $0 ?? nil)
        }
    }

    func loadAlphaPrice() {
        guard !target.isRoot else {
            presenter?.didReceive(alphaPrice: nil)
            return
        }

        catalogueStore.cancel()

        let subnet = target.subnetRef

        load(
            catalogueService.createCatalogueWrapper(),
            in: catalogueStore,
            label: "catalogue for the validator stake"
        ) { [weak self] in
            self?.presenter?.didReceive(alphaPrice: $0?.subnet(for: subnet)?.freshTaoPerAlpha)
        }
    }

    func subscribePrice() {
        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}

extension SubtensorValidatorInfoInteractor: SubtensorValInfoInteractorInputProtocol {
    func cachedSnapshot() -> SubtensorValidatorInfoSnapshot {
        let hotkey = hotkey
        let subnet = target.subnetRef

        return SubtensorValidatorInfoSnapshot(
            annualRate: yieldService.cachedAlphaYields(for: subnet.netuid).map { yields in
                SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields)
            },
            alphaPrice: target.isRoot
                ? .miss
                : catalogueService.cachedCatalogue().map { $0.subnet(for: subnet)?.freshTaoPerAlpha }
        )
    }

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
        subscribePrice()
    }

    func loadDetail() {
        detailStore.cancel()

        executeCancellable(
            wrapper: directoryService.createDetailWrapper(for: hotkey, subnet: target.subnetRef),
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

extension SubtensorValidatorInfoInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceive(price: price)
        case let .failure(error):
            logger.warning("TAO price unavailable: \(error)")
            presenter?.didReceive(price: nil)
        }
    }
}

extension SubtensorValidatorInfoInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        subscribePrice()
    }
}
