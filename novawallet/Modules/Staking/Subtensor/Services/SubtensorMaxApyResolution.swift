import Foundation
import Operation_iOS

final class SubtensorMaxApyResolution {
    typealias Completion = (Result<Decimal?, Error>) -> Void

    private let mutex = NSLock()
    private var contextGeneration = UUID()
    private var walkId: UUID?
    private var walk: CancellableCall?
    private var waiters: [UUID: Completion] = [:]

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

    var generation: UUID {
        mutex.lock()
        defer { mutex.unlock() }
        return contextGeneration
    }

    func invalidate() {
        mutex.lock()
        contextGeneration = UUID()
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

        let completions = Array(waiters.values)
        let generation = contextGeneration
        waiters = [:]

        mutex.unlock()

        completions.forEach { $0(delivery(result, generation: generation)) }
    }
}
