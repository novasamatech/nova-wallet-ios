import Foundation
import Operation_iOS

final class SubtensorValidatorInfoInteractor: AnyCancellableCleaning {
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
    var subnet: SubtensorSubnetRef {
        SubtensorSubnetRef(netuid: target.netuid, registeredAt: target.subnetInfo?.networkRegisteredAt ?? 0)
    }

    func createRateWrapper() -> CompoundOperationWrapper<Decimal?> {
        let hotkey = hotkey
        let yieldsWrapper = yieldService.createAlphaYieldsWrapper(for: subnet.netuid)

        let mapOperation = ClosureOperation<Decimal?> {
            let yields = try yieldsWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields)
        }

        mapOperation.addDependency(yieldsWrapper.targetOperation)

        return yieldsWrapper.insertingTail(operation: mapOperation)
    }

    func loadRate() {
        guard !target.isRoot else {
            presenter?.didReceive(annualRate: nil)
            return
        }

        rateStore.cancel()

        executeCancellable(
            wrapper: createRateWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rateStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(rate):
                self?.presenter?.didReceive(annualRate: rate)
            case let .failure(error):
                self?.logger.warning("Validator reward rate unavailable: \(error)")
                self?.presenter?.didReceive(annualRate: nil)
            }
        }
    }

    func loadAlphaPrice() {
        guard !target.isRoot else {
            presenter?.didReceive(alphaPrice: nil)
            return
        }

        catalogueStore.cancel()

        let subnet = subnet

        executeCancellable(
            wrapper: catalogueService.createCatalogueWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: catalogueStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(catalogue):
                self?.presenter?.didReceive(alphaPrice: catalogue.subnet(for: subnet)?.freshTaoPerAlpha)
            case let .failure(error):
                self?.logger.warning("Subnet catalogue unavailable for the validator stake: \(error)")
                self?.presenter?.didReceive(alphaPrice: nil)
            }
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
        guard !target.isRoot else {
            return SubtensorValidatorInfoSnapshot(annualRate: .miss, alphaPrice: .miss)
        }

        let hotkey = hotkey
        let subnet = subnet

        return SubtensorValidatorInfoSnapshot(
            annualRate: yieldService.cachedAlphaYields(for: subnet.netuid).map { yields in
                SubtensorAlphaApyFormatter.annualRate(for: hotkey, in: yields)
            },
            alphaPrice: catalogueService.cachedCatalogue().map { $0.subnet(for: subnet)?.freshTaoPerAlpha }
        )
    }

    func setup() {
        executeCancellable(
            wrapper: coverageFactory.createWrapper(for: hotkey),
            inOperationQueue: operationQueue, backingCallIn: coverageStore, runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(value): self?.presenter?.didReceive(coverage: value)
            case let .failure(error):
                self?.logger.warning("Validator coverage unavailable: \(error)")
                self?.presenter?.didReceive(coverage: nil)
            }
        }
        loadRate()
        loadAlphaPrice()
        subscribePrice()
    }

    func loadDetail() {
        detailStore.cancel()

        executeCancellable(
            wrapper: directoryService.createDetailWrapper(for: hotkey, subnet: subnet),
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
