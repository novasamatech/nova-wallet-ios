import Foundation
import Operation_iOS

final class SubtensorCostBasisService {
    static let maxPages = 10
    static let ownTradeSettleTime: TimeInterval = 300

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let timeProvider: () -> TimeInterval

    private let mutex = NSLock()
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
    }
}

private extension SubtensorCostBasisService {
    static func makeLedger(
        from pages: [BittensorApiResult<BittensorApi.OperationCollection>]
    ) -> SubtensorCostBasisLedger {
        SubtensorCostBasisLedger(
            operations: pages.flatMap(\.value.items),
            isHistoryComplete: pages.last?.value.pageInfo.nextPage == nil
        )
    }

    func isSeedBlocked(for accountId: AccountId, accountSubject: AccountAddress) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }

        guard let blockedUntil = seedBlockedUntil[accountId] else {
            return false
        }

        if timeProvider() >= blockedUntil {
            seedBlockedUntil[accountId] = nil
            apiOperationFactory.dropOperations(accountSubject: accountSubject)
        }

        return true
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

        let pagesWrapper = BittensorApiPagination.createPagesWrapper(
            maxPages: Self.maxPages,
            operationQueue: operationQueue,
            nextPage: { $0.pageInfo.nextPage },
            pageWrapper: { [apiOperationFactory] page in
                apiOperationFactory.createOperationsWrapper(accountSubject: accountSubject, page: page)
            }
        )

        let mappingOperation = ClosureOperation<SubtensorCostBasis> {
            let pages = try pagesWrapper.targetOperation.extractNoCancellableResultData()
            return try Self.makeLedger(from: pages).costBasis(for: netuid)
        }

        mappingOperation.addDependency(pagesWrapper.targetOperation)

        return pagesWrapper.insertingTail(operation: mappingOperation)
    }

    func cachedCostBasis(for accountId: AccountId, netuid: UInt16) -> HTTPCachePeek<SubtensorCostBasis> {
        guard
            let accountSubject = try? accountId.toAddress(using: .defaultSubstrateFormat),
            !isSeedBlocked(for: accountId, accountSubject: accountSubject) else {
            return .miss
        }

        return BittensorApiPagination.peekPages(
            maxPages: Self.maxPages,
            nextPage: { $0.pageInfo.nextPage },
            peekPage: { [apiOperationFactory] page in
                apiOperationFactory.peekOperations(accountSubject: accountSubject, page: page)
            }
        ).map { try Self.makeLedger(from: $0).costBasis(for: netuid) }
    }
}

extension SubtensorCostBasisService: EventVisitorProtocol {
    func processSubtensorStakingChanged(event: SubtensorStakingChanged) {
        guard let accountSubject = try? event.accountId.toAddress(using: .defaultSubstrateFormat) else {
            return
        }

        apiOperationFactory.dropOperations(accountSubject: accountSubject)

        mutex.lock()
        seedBlockedUntil[event.accountId] = timeProvider() + Self.ownTradeSettleTime
        mutex.unlock()
    }
}
