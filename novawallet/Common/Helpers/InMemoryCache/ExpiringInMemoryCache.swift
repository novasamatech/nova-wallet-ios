import Foundation

final class ExpiringInMemoryCache<K: Hashable, V> {
    private let internalCache: InMemoryCache<K, V>
    private let expirationPeriod: TimeInterval?
    private let mutex = NSLock()

    private var expirationDate: Date?

    init(expirationPeriod: TimeInterval?) {
        internalCache = .init()
        self.expirationPeriod = expirationPeriod
    }
}

// MARK: - Private

private extension ExpiringInMemoryCache {
    func resetExpirationDate() {
        guard let expirationPeriod else { return }

        mutex.lock()

        expirationDate = Date().addingTimeInterval(expirationPeriod)

        mutex.unlock()
    }
}

// MARK: - Internal

extension ExpiringInMemoryCache {
    func fetchValue(for key: K) -> V? {
        mutex.lock()
        defer { mutex.unlock() }

        guard let expirationDate else {
            return internalCache.fetchValue(for: key)
        }

        guard expirationDate < Date() else {
            internalCache.removeAllValues()
            return nil
        }

        return internalCache.fetchValue(for: key)
    }

    func store(value: V, for key: K) {
        internalCache.store(value: value, for: key)
        resetExpirationDate()
    }

    func fetchAllValues() -> [V] {
        mutex.lock()
        defer { mutex.unlock() }

        guard let expirationDate else {
            return internalCache.fetchAllValues()
        }

        guard expirationDate < Date() else {
            internalCache.removeAllValues()
            return []
        }

        return internalCache.fetchAllValues()
    }

    func removeValue(for key: K) {
        internalCache.removeValue(for: key)
    }

    func removeAllValues() {
        mutex.lock()
        defer { mutex.unlock() }

        expirationDate = nil
        internalCache.removeAllValues()
    }
}
