import Foundation
import Operation_iOS

final class SubtensorCostBasisService {
    typealias Completion = (Result<SubtensorCostBasis, Error>) -> Void

    static let memoLifetime: TimeInterval = 900
    static let ownTradeSettleTime: TimeInterval = 300

    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let operationQueue: OperationQueue
    let walkSettings: SubtensorCostBasisWalk.Settings
    let timeProvider: () -> TimeInterval
    let logger: LoggerProtocol

    private let mutex = NSLock()
    private var contextGeneration = UUID()
    private var histories: [AccountId: AccountHistory] = [:]

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        operationQueue: OperationQueue,
        eventCenter: EventCenterProtocol,
        walkSettings: SubtensorCostBasisWalk.Settings = .standard,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.operationQueue = operationQueue
        self.walkSettings = walkSettings
        self.timeProvider = timeProvider
        self.logger = logger

        eventCenter.add(observer: self, dispatchIn: nil)
        apiOperationFactory.addContextObserver(self) { [weak self] in self?.invalidate() }
    }
}

extension SubtensorCostBasisService: SubtensorCostBasisServiceProtocol {
    func createCostBasisWrapper(
        for accountId: AccountId,
        netuid: UInt16
    ) -> CompoundOperationWrapper<SubtensorCostBasis> {
        let waiterId = UUID()
        mutex.lock()
        let generation = contextGeneration
        mutex.unlock()

        let operation = AsyncClosureOperation<SubtensorCostBasis>(
            operationClosure: { [self] completion in
                resolve(
                    accountId: accountId, netuid: netuid, waiterId: waiterId,
                    generation: generation, completion: completion
                )
            },
            cancelationClosure: { [weak self] in
                self?.leave(accountId: accountId, waiterId: waiterId)
            }
        )

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func cachedCostBasis(for accountId: AccountId, netuid: UInt16) -> HTTPCachePeek<SubtensorCostBasis> {
        mutex.lock()

        let memo = histories[accountId]?.memo

        mutex.unlock()

        guard
            let memo,
            timeProvider() - memo.resolvedAt < Self.memoLifetime,
            let costBasis = try? memo.ledger.costBasis(for: netuid) else {
            return .miss
        }

        return .fresh(costBasis, freshUntil: memo.resolvedAt + Self.memoLifetime)
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
    func delivery(_ result: Result<SubtensorCostBasis, Error>, generation: UUID) -> Result<SubtensorCostBasis, Error> {
        mutex.lock()
        defer { mutex.unlock() }
        return generation == contextGeneration
            ? result
            : .failure(BittensorApiError.attestationUnavailable(requestId: nil))
    }

    func invalidate() {
        mutex.lock()
        contextGeneration = UUID()
        let abandoned = Array(histories.values)
        histories = [:]
        mutex.unlock()

        for history in abandoned {
            history.walk?.cancel()
            history.waiters.values.forEach {
                $0.completion(.failure(BittensorApiError.attestationUnavailable(requestId: nil)))
            }
        }
    }

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

    func resolve(
        accountId: AccountId,
        netuid: UInt16,
        waiterId: UUID,
        generation: UUID,
        completion: @escaping Completion
    ) {
        let accountSubject: AccountAddress

        do {
            accountSubject = try accountId.toAddress(using: .defaultSubstrateFormat)
        } catch {
            completion(.failure(error))

            return
        }

        mutex.lock()

        guard generation == contextGeneration else {
            mutex.unlock()
            completion(.failure(BittensorApiError.attestationUnavailable(requestId: nil)))
            return
        }

        var history = histories[accountId] ?? AccountHistory()

        if let memo = history.memo, timeProvider() - memo.resolvedAt < Self.memoLifetime {
            mutex.unlock()

            completion(delivery(Result { try memo.ledger.costBasis(for: netuid) }, generation: generation))

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
        let generation = contextGeneration
        history.waiters = [:]

        histories[accountId] = history

        mutex.unlock()

        if case let .failure(error) = result {
            logger.warning("Subtensor cost basis history unavailable: \(error)")
        }

        for waiter in waiters {
            let costBasis = result.flatMap { ledger in Result { try ledger.costBasis(for: waiter.netuid) } }
            waiter.completion(delivery(costBasis, generation: generation))
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
