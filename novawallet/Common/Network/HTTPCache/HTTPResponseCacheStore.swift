import Foundation
import Operation_iOS

enum HTTPCacheFetchOutcome<Value> {
    case response(Value, HTTPCacheDirectives)
    case cached(Value, isExpired: Bool)
}

struct HTTPCacheDelivery<Value> {
    let value: Value
    let isExpired: Bool
}

final class HTTPResponseCacheStore<Key: Hashable, Value> {
    typealias Fetch = () -> CompoundOperationWrapper<HTTPCacheFetchOutcome<Value>>
    typealias Completion = (Result<HTTPCacheDelivery<Value>, Error>) -> Void

    private let operationQueue: OperationQueue
    private let timeProvider: () -> TimeInterval
    private let mutex = NSLock()

    private var entries: [Key: Entry] = [:]
    private var inFlightFetches: [Key: InFlightFetch] = [:]

    init(operationQueue: OperationQueue, timeProvider: @escaping () -> TimeInterval) {
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
    }

    func peek(_ key: Key) -> HTTPCachePeek<Value> {
        let now = timeProvider()

        mutex.lock()

        let entry = entries[key]

        mutex.unlock()

        return entry?.peek(at: now) ?? .miss
    }

    func request(
        _ key: Key,
        waiterId: UUID,
        fetch: @escaping Fetch,
        completion: @escaping Completion
    ) {
        let now = timeProvider()

        mutex.lock()

        if let entry = entries[key], entry.isFresh(at: now) {
            mutex.unlock()

            completion(.success(HTTPCacheDelivery(value: entry.value, isExpired: false)))

            return
        }

        let shouldStartFetch = inFlightFetches[key] == nil

        if shouldStartFetch {
            inFlightFetches[key] = InFlightFetch(fetchStartedAt: now)
        }

        inFlightFetches[key]?.waiters.append(Waiter(id: waiterId, completion: completion))

        mutex.unlock()

        if shouldStartFetch {
            startFetch(for: key, fetch: fetch)
        }
    }

    func removeWaiter(_ waiterId: UUID, for key: Key) {
        mutex.lock()

        inFlightFetches[key]?.waiters.removeAll { $0.id == waiterId }

        mutex.unlock()
    }

    func removeAll(where shouldRemove: (Value) -> Bool) {
        mutex.lock()

        entries = entries.filter { _, entry in !shouldRemove(entry.value) }

        mutex.unlock()
    }
}

private extension HTTPResponseCacheStore {
    struct Entry {
        let value: Value
        let freshUntil: TimeInterval

        func isFresh(at now: TimeInterval) -> Bool {
            now < freshUntil
        }

        func peek(at now: TimeInterval) -> HTTPCachePeek<Value> {
            isFresh(at: now) ? .fresh(value, freshUntil: freshUntil) : .expired(value)
        }
    }

    struct Waiter {
        let id: UUID
        let completion: Completion
    }

    struct InFlightFetch {
        let fetchStartedAt: TimeInterval
        var waiters: [Waiter] = []
    }

    func startFetch(for key: Key, fetch: Fetch) {
        execute(
            wrapper: fetch(),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { result in
            self.completeFetch(for: key, result: result)
        }
    }

    func completeFetch(for key: Key, result: Result<HTTPCacheFetchOutcome<Value>, Error>) {
        let now = timeProvider()

        mutex.lock()

        let inFlightFetch = inFlightFetches.removeValue(forKey: key)

        if
            let inFlightFetch,
            case let .success(.response(value, .reusable(lifetime))) = result,
            inFlightFetch.fetchStartedAt + lifetime > now {
            entries[key] = Entry(value: value, freshUntil: inFlightFetch.fetchStartedAt + lifetime)
        }

        mutex.unlock()

        let delivery = result.map(\.delivery)

        inFlightFetch?.waiters.forEach { $0.completion(delivery) }
    }
}

private extension HTTPCacheFetchOutcome {
    var delivery: HTTPCacheDelivery<Value> {
        switch self {
        case let .response(value, _):
            return HTTPCacheDelivery(value: value, isExpired: false)
        case let .cached(value, isExpired):
            return HTTPCacheDelivery(value: value, isExpired: isExpired)
        }
    }
}
