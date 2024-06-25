import Foundation

class InMemoryCache<K: Hashable, V> {
    private var cache: [K: V] = [:]
    private let mutex = NSLock()

    func fetchValue(for key: K) -> V? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return cache[key]
    }

    func store(value: V, for key: K) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cache[key] = value
    }
}
