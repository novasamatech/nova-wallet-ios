import Foundation

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
