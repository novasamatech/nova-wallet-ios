import Foundation

class InMemoryCache<K: Hashable, V> {
    private var cache: [K: V]
    private let mutex = NSLock()

    required init(with dict: [K: V] = [:]) {
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

    func copy() -> Self {
        mutex.lock()
        defer { mutex.unlock() }

        return .init(with: cache)
    }
}

extension InMemoryCache: Equatable where V: Equatable {
    static func == (lhs: InMemoryCache<K, V>, rhs: InMemoryCache<K, V>) -> Bool {
        lhs.cache == rhs.cache
    }
}

struct ObservableInMemoryCache<K: Hashable, V> {
    var cache: InMemoryCache<K, V> {
        internalCache
    }

    private var internalCache: InMemoryCache<K, V>

    init(with dict: [K: V] = [:]) {
        internalCache = InMemoryCache(with: dict)
    }

    func fetchValue(for key: K) -> V? {
        internalCache.fetchValue(for: key)
    }

    mutating func store(value: V, for key: K) {
        copyIfNeeded()
        internalCache.store(value: value, for: key)
    }

    func fetchAllValues() -> [V] {
        internalCache.fetchAllValues()
    }

    func fetchAllKeys() -> [K] {
        internalCache.fetchAllKeys()
    }

    mutating func removeValue(for key: K) {
        copyIfNeeded()
        internalCache.removeValue(for: key)
    }

    mutating func removeAllValues() {
        copyIfNeeded()
        internalCache.removeAllValues()
    }

    private mutating func copyIfNeeded() {
        if !isKnownUniquelyReferenced(&internalCache) {
            internalCache = internalCache.copy()
        }
    }
}

extension ObservableInMemoryCache: Equatable {
    static func == (
        _: ObservableInMemoryCache<K, V>,
        _: ObservableInMemoryCache<K, V>
    ) -> Bool {
        false
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
