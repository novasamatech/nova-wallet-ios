import Foundation
import Operation_iOS

final class SubtensorSubnetSelectInteractor {
    weak var presenter: SubnetSelectInteractorOutputProtocol?

    let catalogueService: SubtensorSubnetCatalogueServiceProtocol
    let subnetsService: SubtensorSubnetsServiceProtocol
    let subnetLogosProvider: SubtensorSubnetLogosProviderProtocol
    let priceHistoryService: SubtensorPriceHistoryServiceProtocol?
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var seed = SubtensorSubnetSelectSnapshot(entries: .miss)
    private let entriesStore = CancellableCallStore()
    private let logosStore = CancellableCallStore()
    private let weeklyStore = CancellableCallStore()

    init(
        catalogueService: SubtensorSubnetCatalogueServiceProtocol,
        subnetsService: SubtensorSubnetsServiceProtocol,
        subnetLogosProvider: SubtensorSubnetLogosProviderProtocol,
        priceHistoryService: SubtensorPriceHistoryServiceProtocol?,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.catalogueService = catalogueService
        self.subnetsService = subnetsService
        self.subnetLogosProvider = subnetLogosProvider
        self.priceHistoryService = priceHistoryService
        self.operationQueue = operationQueue
        self.logger = logger
    }

    deinit {
        [entriesStore, logosStore, weeklyStore].forEach { $0.cancel() }
    }
}

private extension SubtensorSubnetSelectInteractor {
    func createEntriesWrapper(forcingRefresh: Bool) -> CompoundOperationWrapper<[SubtensorSubnetListEntry]> {
        let catalogueWrapper = catalogueService.createCatalogueWrapper()
        let subnetsService = subnetsService

        let subnetsInfoOperation = AsyncClosureOperation<SubtensorSubnetsInfo> { completion in
            subnetsService.fetchSubnetsInfo(
                forcingRefresh: forcingRefresh, runningCompletionIn: .global(), completion: completion
            )
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

    func provideEntries(forcingRefresh: Bool = false) {
        entriesStore.cancel()

        executeCancellable(
            wrapper: createEntriesWrapper(forcingRefresh: forcingRefresh),
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
            entries: makeCachedEntries()
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
    }

    func refresh() {
        provideEntries(forcingRefresh: true)
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
