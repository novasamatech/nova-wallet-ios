import Foundation
import Operation_iOS

final class SubtensorCostBasisService {
    typealias Completion = (Result<SubtensorCostBasis, Error>) -> Void

    static let defaultMemoLifetime: TimeInterval = 900
    static let ownTradeSettleTime: TimeInterval = 300

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let walkSettings: SubtensorCostBasisWalk.Settings
    let memoLifetime: TimeInterval
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var histories: [AccountId: AccountHistory] = [:]

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        walkSettings: SubtensorCostBasisWalk.Settings = .standard,
        memoLifetime: TimeInterval = SubtensorCostBasisService.defaultMemoLifetime,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.operationQueue = operationQueue
        self.walkSettings = walkSettings
        self.memoLifetime = memoLifetime
        self.timeProvider = timeProvider
        self.logger = logger

        eventCenter.add(observer: self, dispatchIn: nil)
    }
}

extension SubtensorCostBasisService: SubtensorCostBasisServiceProtocol {
    func createCostBasisWrapper(
        for accountId: AccountId,
        netuid: UInt16
    ) -> CompoundOperationWrapper<SubtensorCostBasis> {
        let waiterId = UUID()

        let operation = AsyncClosureOperation<SubtensorCostBasis>(
            operationClosure: { [self] completion in
                resolve(accountId: accountId, netuid: netuid, waiterId: waiterId, completion: completion)
            },
            cancelationClosure: { [weak self] in
                self?.leave(accountId: accountId, waiterId: waiterId)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

extension SubtensorCostBasisService: EventVisitorProtocol {
    func processSubtensorStakingChanged(event: SubtensorStakingChanged) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        var history = histories[event.accountId] ?? AccountHistory()

        history.memo = nil
        history.memoBlockedUntil = timeProvider() + Self.ownTradeSettleTime

        histories[event.accountId] = history
    }
}

private extension SubtensorCostBasisService {
    struct Waiter {
        let netuid: UInt16
        let completion: Completion
    }

    struct Memo {
        let ledger: SubtensorCostBasisLedger
        let resolvedAt: TimeInterval
    }

    struct AccountHistory {
        var memo: Memo?
        var memoBlockedUntil: TimeInterval?
        var walkId: UUID?
        var walk: CancellableCall?
        var waiters: [UUID: Waiter] = [:]
    }

    func resolve(accountId: AccountId, netuid: UInt16, waiterId: UUID, completion: @escaping Completion) {
        let accountSubject: AccountAddress

        do {
            accountSubject = try accountId.toAddress(using: .defaultSubstrateFormat)
        } catch {
            completion(.failure(error))

            return
        }

        mutex.lock()

        var history = histories[accountId] ?? AccountHistory()

        if let memo = history.memo, timeProvider() - memo.resolvedAt < memoLifetime {
            mutex.unlock()

            completion(Result { try memo.ledger.costBasis(for: netuid) })

            return
        }

        history.waiters[waiterId] = Waiter(netuid: netuid, completion: completion)

        var newWalk: SubtensorCostBasisWalk?
        let walkId = history.walkId ?? UUID()

        if history.walkId == nil {
            let walk = makeWalk(for: accountSubject)

            history.walkId = walkId
            history.walk = walk
            newWalk = walk
        }

        histories[accountId] = history

        mutex.unlock()

        newWalk?.start { [weak self] result in
            self?.complete(accountId: accountId, walkId: walkId, result: result)
        }
    }

    func leave(accountId: AccountId, waiterId: UUID) {
        mutex.lock()

        guard var history = histories[accountId] else {
            mutex.unlock()

            return
        }

        history.waiters[waiterId] = nil

        let abandonedWalk = history.waiters.isEmpty ? history.walk : nil

        if abandonedWalk != nil {
            history.walkId = nil
            history.walk = nil
        }

        histories[accountId] = history

        mutex.unlock()

        abandonedWalk?.cancel()
    }

    func complete(accountId: AccountId, walkId: UUID, result: Result<SubtensorCostBasisLedger, Error>) {
        mutex.lock()

        guard var history = histories[accountId], history.walkId == walkId else {
            mutex.unlock()

            return
        }

        let now = timeProvider()

        history.walkId = nil
        history.walk = nil

        if case let .success(ledger) = result, now >= history.memoBlockedUntil ?? now {
            history.memo = Memo(ledger: ledger, resolvedAt: now)
        }

        let waiters = Array(history.waiters.values)
        history.waiters = [:]

        histories[accountId] = history

        mutex.unlock()

        if case let .failure(error) = result {
            logger.warning("Subtensor cost basis history unavailable: \(error)")
        }

        for waiter in waiters {
            waiter.completion(result.flatMap { ledger in Result { try ledger.costBasis(for: waiter.netuid) } })
        }
    }

    func makeWalk(for accountSubject: AccountAddress) -> SubtensorCostBasisWalk {
        SubtensorCostBasisWalk(
            accountSubject: accountSubject,
            apiOperationFactory: apiOperationFactory,
            operationQueue: operationQueue,
            settings: walkSettings,
            timeProvider: timeProvider,
            logger: logger
        )
    }
}
