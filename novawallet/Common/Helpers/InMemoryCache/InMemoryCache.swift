import Foundation

final class InMemoryCache<K: Hashable, V> {
    private var cache: [K: V]
    private let mutex = NSLock()

    init(with dict: [K: V] = [:]) {
        cache = dict
    }

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

    func fetchAllValues() -> [V] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Array(cache.values)
    }

    func fetchAllKeys() -> [K] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Array(cache.keys)
    }

    func fetchAllPairs() -> [(K, V)] {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Array(cache).map { ($0.key, $0.value) }
    }

    func removeValue(for key: K) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cache[key] = nil
    }

    func removeAllValues() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        cache.removeAll()
    }
}

extension InMemoryCache: Equatable where V: Equatable {
    static func == (lhs: InMemoryCache<K, V>, rhs: InMemoryCache<K, V>) -> Bool {
        lhs.cache == rhs.cache
    }
}
