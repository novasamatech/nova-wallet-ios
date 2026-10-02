import Foundation
import Operation_iOS

final class SubtensorSubnetSelectInteractor {
    weak var presenter: SubnetSelectInteractorOutputProtocol?

    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let yieldService: SubtensorYieldServiceProtocol
    let rankingViewService: SubtensorRankingViewServiceProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var seed = SubtensorSubnetSelectSnapshot(entries: .miss, rootRate: .miss, rankedSubnets: .miss)
    private let entriesStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let rootRateStore = CancellableCallStore()
    private let rankingStore = CancellableCallStore()
    private let weeklyStore = CancellableCallStore()

    init(
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        yieldService: SubtensorYieldServiceProtocol,
        rankingViewService: SubtensorRankingViewServiceProtocol,
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.catalogueService = catalogueService
        self.subnetsService = subnetsService
        self.subnetLogosProvider = subnetLogosProvider
        self.yieldService = yieldService
        self.rankingViewService = rankingViewService
        self.priceHistoryService = priceHistoryService
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        [entriesStore, logosStore, rootRateStore, rankingStore, weeklyStore].forEach { $0.cancel() }
    }
}

private extension SubtensorSubnetSelectInteractor {
    func createEntriesWrapper() -> CompoundOperationWrapper<[SubtensorSubnetListEntry]> {
        let catalogueWrapper = catalogueService.createCatalogueWrapper()
        let subnetsService = subnetsService

        let subnetsInfoOperation = AsyncClosureOperation<SubtensorSubnetsInfo> { completion in
            subnetsService.fetchSubnetsInfo(runningCompletionIn: .global(), completion: completion)
        }

        let entriesOperation = ClosureOperation<[SubtensorSubnetListEntry]> {
            let catalogue = try catalogueWrapper.targetOperation.extractNoCancellableResultData()
            let subnetsInfo = try subnetsInfoOperation.extractNoCancellableResultData()

            return SubtensorSubnetListBuilder.entries(from: catalogue, subnetsInfo: subnetsInfo)
        }

        entriesOperation.addDependency(catalogueWrapper.targetOperation)
        entriesOperation.addDependency(subnetsInfoOperation)

        return catalogueWrapper
            .insertingHead(operations: [subnetsInfoOperation])
            .insertingTail(operation: entriesOperation)
    }

    func provideEntries() {
        entriesStore.cancel()

        executeCancellable(
            wrapper: createEntriesWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: entriesStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(entries):
                self?.presenter?.didReceive(entries: entries)
            case let .failure(error):
                self?.logger.error("Subnet list unavailable: \(error)")
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func provideSubnetLogos() {
        executeCancellable(
            wrapper: subnetLogosProvider.createLogosWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: logosStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(logos):
                self?.presenter?.didReceive(subnetLogos: logos)
            case let .failure(error):
                self?.logger.warning("Subnet marks unavailable: \(error)")
                self?.presenter?.didReceive(subnetLogos: nil)
            }
        }
    }

    func provideRootRate() {
        executeCancellable(
            wrapper: yieldService.createRootYieldWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rootRateStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(yield):
                self?.presenter?.didReceive(rootRate: yield?.annualRate)
            case let .failure(error):
                self?.logger.warning("Root rate unavailable: \(error)")
                self?.presenter?.didReceive(rootRate: nil)
            }
        }
    }

    func provideRankingView() {
        executeCancellable(
            wrapper: rankingViewService.createRankingViewWrapper(),
            inOperationQueue: operationQueue,
            backingCallIn: rankingStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(rankedSubnets):
                self?.presenter?.didReceive(rankedSubnets: rankedSubnets)
            case let .failure(error):
                self?.logger.warning("Subnet ages unavailable: \(error)")
                self?.presenter?.didReceive(rankedSubnets: nil)
            }
        }
    }

    func unavailablePrices<Value: Equatable>(
        for subnets: [SubtensorSubnetRef]
    ) -> [SubtensorSubnetRef: SubtensorPriceData<Value>] {
        Dictionary(subnets.map { ($0, .unavailable) }, uniquingKeysWith: { first, _ in first })
    }

    func makeCachedEntries() -> HTTPCachePeek<[SubtensorSubnetListEntry]> {
        guard let subnetsInfo = subnetsService.cachedSubnetsInfo() else {
            return .miss
        }

        return catalogueService.cachedCatalogue().map { catalogue in
            SubtensorSubnetListBuilder.entries(from: catalogue, subnetsInfo: subnetsInfo)
        }
    }

    func makeSnapshot() -> SubtensorSubnetSelectSnapshot {
        SubtensorSubnetSelectSnapshot(
            entries: makeCachedEntries(),
            rootRate: yieldService.cachedRootYield().map { $0?.annualRate },
            rankedSubnets: rankingViewService.cachedRankingView()
        )
    }
}

extension SubtensorSubnetSelectInteractor: SubnetSelectInteractorInputProtocol {
    func cachedSnapshot() -> SubtensorSubnetSelectSnapshot {
        seed = makeSnapshot()

        return seed
    }

    func setup() {
        if !seed.entries.isFresh {
            provideEntries()
        }

        provideSubnetLogos()

        if !seed.rootRate.isFresh {
            provideRootRate()
        }

        if !seed.rankedSubnets.isFresh {
            provideRankingView()
        }
    }

    func refresh() {
        provideEntries()
    }

    func loadWeeklyPrices(for subnets: [SubtensorSubnetRef]) {
        weeklyStore.cancel()

        guard let priceHistoryService else {
            presenter?.didReceive(weeklyPrices: unavailablePrices(for: subnets))
            return
        }

        executeCancellable(
            wrapper: priceHistoryService.createWeeklyChangesWrapper(for: subnets),
            inOperationQueue: operationQueue,
            backingCallIn: weeklyStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(prices):
                presenter?.didReceive(weeklyPrices: prices)
            case let .failure(error):
                logger.warning("Subnet weekly prices unavailable: \(error)")
                presenter?.didReceive(weeklyPrices: unavailablePrices(for: subnets))
            }
        }
    }
}
