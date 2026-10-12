import Foundation
import Operation_iOS

final class SubtensorMaxApyResolution {
    typealias Completion = (Result<Decimal?, Error>) -> Void

    static let defaultMemoLifetime: TimeInterval = 3600

    let memoLifetime: TimeInterval
    let timeProvider: () -> TimeInterval

    private let mutex = NSLock()
    private var contextGeneration = UUID()
    private var memo: Memo?
    private var walkId: UUID?
    private var walk: CancellableCall?
    private var waiters: [UUID: Completion] = [:]

    init(
        memoLifetime: TimeInterval = SubtensorMaxApyResolution.defaultMemoLifetime,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now
    ) {
        self.memoLifetime = memoLifetime
        self.timeProvider = timeProvider
    }

    func resolve(
        for waiterId: UUID,
        generation: UUID,
        startingWalkWith startWalk: (@escaping Completion) -> CancellableCall,
        completion: @escaping Completion
    ) {
        mutex.lock()

        guard generation == contextGeneration else {
            mutex.unlock()
            completion(.failure(BittensorApiError.attestationUnavailable(requestId: nil)))
            return
        }

        if let memo, timeProvider() - memo.resolvedAt < memoLifetime {
            mutex.unlock()

            completion(delivery(.success(memo.maxApy), generation: generation))

            return
        }

        waiters[waiterId] = completion

        guard walkId == nil else {
            mutex.unlock()

            return
        }

        let newWalkId = UUID()
        walkId = newWalkId

        mutex.unlock()

        let newWalk = startWalk { [weak self] result in
            self?.complete(walkId: newWalkId, with: result)
        }

        mutex.lock()

        let isAbandoned = walkId != newWalkId

        if !isAbandoned {
            walk = newWalk
        }

        mutex.unlock()

        if isAbandoned {
            newWalk.cancel()
        }
    }

    func leave(_ waiterId: UUID) {
        mutex.lock()

        waiters[waiterId] = nil

        guard waiters.isEmpty, walkId != nil else {
            mutex.unlock()

            return
        }

        let abandonedWalk = walk

        walk = nil
        walkId = nil

        mutex.unlock()

        abandonedWalk?.cancel()
    }

    func peek() -> HTTPCachePeek<Decimal?> {
        mutex.lock()

        let memo = memo

        mutex.unlock()

        guard let memo, timeProvider() - memo.resolvedAt < memoLifetime else {
            return .miss
        }

        return .fresh(memo.maxApy, freshUntil: memo.resolvedAt + memoLifetime)
    }

    var generation: UUID {
        mutex.lock()
        defer { mutex.unlock() }
        return contextGeneration
    }

    func invalidate() {
        mutex.lock()
        contextGeneration = UUID()
        memo = nil
        walkId = nil
        let abandonedWalk = walk
        let completions = Array(waiters.values)
        walk = nil
        waiters = [:]
        mutex.unlock()

        abandonedWalk?.cancel()
        completions.forEach { $0(.failure(BittensorApiError.attestationUnavailable(requestId: nil))) }
    }
}

private extension SubtensorMaxApyResolution {
    struct Memo {
        let maxApy: Decimal?
        let resolvedAt: TimeInterval
    }

    func delivery(_ result: Result<Decimal?, Error>, generation: UUID) -> Result<Decimal?, Error> {
        mutex.lock()
        defer { mutex.unlock() }
        return generation == contextGeneration
            ? result
            : .failure(BittensorApiError.attestationUnavailable(requestId: nil))
    }

    func complete(walkId completedWalkId: UUID, with result: Result<Decimal?, Error>) {
        mutex.lock()

        guard walkId == completedWalkId else {
            mutex.unlock()

            return
        }

        walkId = nil
        walk = nil

        if case let .success(maxApy) = result {
            memo = Memo(maxApy: maxApy, resolvedAt: timeProvider())
        }

        let completions = Array(waiters.values)
        let generation = contextGeneration
        waiters = [:]

        mutex.unlock()

        completions.forEach { $0(delivery(result, generation: generation)) }
    }
}
