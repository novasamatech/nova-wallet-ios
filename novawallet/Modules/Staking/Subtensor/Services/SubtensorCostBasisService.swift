import Foundation
import Operation_iOS

final class SubtensorCostBasisService {
    static let maxPages = 10
    static let ownTradeSettleTime: TimeInterval = 300

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let timeProvider: () -> TimeInterval

    private let mutex = NSLock()
    private var contextGeneration = UUID()
    private var seeds: [AccountId: SubtensorCostBasisLedger] = [:]
    private var seedBlockedUntil: [AccountId: TimeInterval] = [:]

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider

        eventCenter.add(observer: self, dispatchIn: nil)
        apiOperationFactory.addContextObserver(self) { [weak self] in self?.invalidate() }
    }
}

extension SubtensorCostBasisService: SubtensorCostBasisServiceProtocol {
    func createCostBasisWrapper(
        for accountId: AccountId,
        netuid: UInt16
    ) -> CompoundOperationWrapper<SubtensorCostBasis> {
        let accountSubject: AccountAddress

        do {
            accountSubject = try accountId.toAddress(using: .defaultSubstrateFormat)
        } catch {
            return .createWithError(error)
        }

        mutex.lock()
        let generation = contextGeneration
        mutex.unlock()

        let pagesWrapper = BittensorApiPagination.createPagesWrapper(
            maxPages: Self.maxPages,
            operationQueue: operationQueue,
            nextPage: { $0.pageInfo.nextPage },
            pageWrapper: { [apiOperationFactory] page in
                apiOperationFactory.createOperationsWrapper(accountSubject: accountSubject, page: page)
            }
        )

        let mappingOperation = ClosureOperation<SubtensorCostBasis> { [weak self] in
            let pages = try pagesWrapper.targetOperation.extractNoCancellableResultData()

            let ledger = SubtensorCostBasisLedger(
                operations: pages.pages.flatMap(\.value.items),
                isHistoryComplete: pages.pages.last?.value.pageInfo.nextPage == nil
            )

            try self?.store(ledger, for: accountId, generation: generation)

            return try ledger.costBasis(for: netuid)
        }

        mappingOperation.addDependency(pagesWrapper.targetOperation)

        return pagesWrapper.insertingTail(operation: mappingOperation)
    }

    func cachedCostBasis(for accountId: AccountId, netuid: UInt16) -> HTTPCachePeek<SubtensorCostBasis> {
        mutex.lock()
        let ledger = seeds[accountId]
        mutex.unlock()

        guard let costBasis = try? ledger?.costBasis(for: netuid) else {
            return .miss
        }

        return .expired(costBasis)
    }
}

extension SubtensorCostBasisService: EventVisitorProtocol {
    func processSubtensorStakingChanged(event: SubtensorStakingChanged) {
        mutex.lock()
        seeds[event.accountId] = nil
        seedBlockedUntil[event.accountId] = timeProvider() + Self.ownTradeSettleTime
        mutex.unlock()
    }
}

private extension SubtensorCostBasisService {
    func store(_ ledger: SubtensorCostBasisLedger, for accountId: AccountId, generation: UUID) throws {
        mutex.lock()
        defer { mutex.unlock() }

        guard generation == contextGeneration else {
            throw BittensorApiError.unavailable(code: nil, requestId: nil)
        }

        if timeProvider() >= seedBlockedUntil[accountId] ?? 0 {
            seeds[accountId] = ledger
        }
    }

    func invalidate() {
        mutex.lock()
        contextGeneration = UUID()
        seeds = [:]
        seedBlockedUntil = [:]
        mutex.unlock()
    }
}
