import Foundation
import Operation_iOS

struct BittensorApiCacheKey: Hashable {
    let path: String
    let query: [String]
}

struct BittensorApiGenerationOrder: Comparable {
    let asOf: Date
    let sourceBlockNumber: UInt64

    static func < (lhs: BittensorApiGenerationOrder, rhs: BittensorApiGenerationOrder) -> Bool {
        lhs.asOf == rhs.asOf ? lhs.sourceBlockNumber < rhs.sourceBlockNumber : lhs.asOf < rhs.asOf
    }
}

struct BittensorApiFetchedValue {
    let value: Any
    let requestId: String?
    let generation: BittensorApiGenerationOrder?
    let directives: HTTPCacheDirectives
}

struct BittensorApiCacheEntry {
    let value: Any
    let requestId: String?
    let generation: BittensorApiGenerationOrder?
    let freshUntil: TimeInterval
}

struct BittensorApiCacheJob {
    let key: BittensorApiCacheKey
    let currentInvalidationRevision: () -> UInt64
    let admit: () -> CompoundOperationWrapper<BittensorApiAdmission>
    let fetch: (BittensorApiAdmission) -> CompoundOperationWrapper<BittensorApiFetchedValue>
}

final class BittensorApiResponseCache {
    private struct ScopedKey: Hashable {
        let scope: BittensorApiCacheScope
        let request: BittensorApiCacheKey
    }

    private let operationQueue: OperationQueue
    private let timeProvider: () -> TimeInterval
    private let mutex = NSLock()
    private var entries: [ScopedKey: BittensorApiCacheEntry] = [:]
    private var activeScope: BittensorApiCacheScope?
    private var minimumInvalidationRevision: UInt64 = 0
    private var newestGeneration: BittensorApiGenerationOrder?

    init(operationQueue: OperationQueue, timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now) {
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
    }

    func invalidate(before revision: UInt64) {
        mutex.lock()
        invalidateLocked(before: revision)
        mutex.unlock()
    }

    func removeEntries(where predicate: (BittensorApiCacheKey) -> Bool) {
        mutex.lock()
        entries = entries.filter { !predicate($0.key.request) }
        mutex.unlock()
    }

    func peek(_ key: BittensorApiCacheKey, invalidationRevision: UInt64) -> HTTPCachePeek<BittensorApiCacheEntry> {
        mutex.lock()
        defer { mutex.unlock() }
        invalidateLocked(before: invalidationRevision)
        guard let scope = activeScope, let entry = entries[ScopedKey(scope: scope, request: key)] else { return .miss }
        return timeProvider() < entry.freshUntil ? .fresh(entry) : .expired(entry)
    }

    func createWrapper(for job: BittensorApiCacheJob) -> CompoundOperationWrapper<BittensorApiCacheEntry> {
        if case let .fresh(entry) = peek(job.key, invalidationRevision: job.currentInvalidationRevision()) {
            return .createWithResult(entry)
        }
        let admission = job.admit()
        let start = ClosureOperation<TimeInterval> {
            let admitted = try admission.targetOperation.extractNoCancellableResultData()
            try self.activate(admitted.scope, currentRevision: job.currentInvalidationRevision())
            return self.timeProvider()
        }
        start.addDependency(admission.targetOperation)
        let fetch = OperationCombiningService<BittensorApiFetchedValue>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            _ = try start.extractNoCancellableResultData()
            return try job.fetch(admission.targetOperation.extractNoCancellableResultData())
        }
        fetch.addDependency(operations: [start])
        let store = ClosureOperation<BittensorApiCacheEntry> {
            let scope = try admission.targetOperation.extractNoCancellableResultData().scope
            return try self.store(
                key: ScopedKey(scope: scope, request: job.key),
                currentRevision: job.currentInvalidationRevision(),
                startedAt: start.extractNoCancellableResultData()
            ) { try fetch.targetOperation.extractNoCancellableResultData() }
        }
        store.addDependency(fetch.targetOperation)
        return fetch.insertingHead(operations: admission.allOperations + [start]).insertingTail(operation: store)
    }
}

private extension BittensorApiResponseCache {
    func invalidateLocked(before revision: UInt64) {
        guard revision > minimumInvalidationRevision else { return }
        minimumInvalidationRevision = revision
        activeScope = nil
        entries.removeAll()
        newestGeneration = nil
    }

    func activate(_ scope: BittensorApiCacheScope, currentRevision: UInt64) throws {
        mutex.lock()
        defer { mutex.unlock() }
        invalidateLocked(before: max(currentRevision, scope.invalidationRevision))
        guard scope.invalidationRevision >= minimumInvalidationRevision else {
            throw BittensorApiError.unavailable(code: nil, requestId: nil)
        }
        if activeScope != scope {
            activeScope = scope
            entries.removeAll()
            newestGeneration = nil
        }
    }

    private func store(
        key: ScopedKey,
        currentRevision: UInt64,
        startedAt: TimeInterval,
        fetched: () throws -> BittensorApiFetchedValue
    ) throws -> BittensorApiCacheEntry {
        mutex.lock()
        defer { mutex.unlock() }
        invalidateLocked(before: currentRevision)
        guard activeScope == key.scope else {
            throw BittensorApiError.unavailable(code: nil, requestId: nil)
        }
        let fetched = try fetched()
        if let generation = fetched.generation, let newestGeneration, generation < newestGeneration {
            throw BittensorApiError.generationStale
        }
        if let generation = fetched.generation {
            if newestGeneration.map({ $0 < generation }) ?? false {
                entries = entries.filter { $0.value.generation == nil }
            }
            newestGeneration = generation
        }
        let freshUntil: TimeInterval
        switch fetched.directives {
        case let .reusable(lifetime):
            freshUntil = startedAt + lifetime
        case .notStorable:
            freshUntil = startedAt
        }
        let entry = BittensorApiCacheEntry(
            value: fetched.value, requestId: fetched.requestId, generation: fetched.generation, freshUntil: freshUntil
        )
        entries[key] = entry
        return entry
    }
}
