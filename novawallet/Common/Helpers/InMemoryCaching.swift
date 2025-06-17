import Foundation

class InMemoryCache<K: Hashable, V> {
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

struct ObservableInMemoryCache<K: Hashable, V> {
    let internalCache: NotEqualWrapper<InMemoryCache<K, V>>

    init(with dict: [K: V] = [:]) {
        internalCache = .init(value: InMemoryCache(with: dict))
    }

    func fetchValue(for key: K) -> V? {
        internalCache.value.fetchValue(for: key)
    }

    mutating func store(value: V, for key: K) {
        internalCache.value.store(value: value, for: key)
    }

    func fetchAllValues() -> [V] {
        internalCache.value.fetchAllValues()
    }

    func fetchAllKeys() -> [K] {
        internalCache.value.fetchAllKeys()
    }

    mutating func removeValue(for key: K) {
        internalCache.value.removeValue(for: key)
    }

    mutating func removeAllValues() {
        internalCache.value.removeAllValues()
    }
}

extension ObservableInMemoryCache: Equatable {
    static func == (
        lhs: ObservableInMemoryCache<K, V>,
        rhs: ObservableInMemoryCache<K, V>
    ) -> Bool {
        lhs.internalCache == rhs.internalCache
    }
}

extension ObservableInMemoryCache {
    func newItems(
        after olderCache: ObservableInMemoryCache<K, V>
    ) -> [K: V] {
        let lhsKeys = Set(fetchAllKeys())
        let rhsKeys = Set(olderCache.fetchAllKeys())

        let addedKeys = lhsKeys.subtracting(rhsKeys)

        return addedKeys.reduce(into: [K: V]()) { $0[$1] = self.fetchValue(for: $1) }
    }
}
