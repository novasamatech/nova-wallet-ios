import Foundation
import Operation_iOS

enum StorageRepositoryCacheSettings<T> {
    case useCache
    case ignoreCache

    var cacheKey: String {
        String(describing: T.self)
    }
}

protocol InMemoryRepositoryCachingFactory {
    func createInMemoryRepository<T>(
        cacheSettings: StorageRepositoryCacheSettings<T>
    ) -> InMemoryDataProviderRepository<T>
}

private extension InMemoryRepositoryCachingFactory {
    var cache: InMemoryCache<String, WeakWrapper> {
        get {
            objc_getAssociatedObject(self, &Constants.inMemoryRepositoriesKey)
                as? InMemoryCache<String, WeakWrapper> ?? .init()
        }

        set {
            objc_setAssociatedObject(
                self,
                &Constants.inMemoryRepositoriesKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }
}

extension InMemoryRepositoryCachingFactory {
    func createInMemoryRepository<T>(
        cacheSettings: StorageRepositoryCacheSettings<T>
    ) -> InMemoryDataProviderRepository<T> {
        switch cacheSettings {
        case .useCache:
            let key = cacheSettings.cacheKey

            let cached = cache.fetchValue(for: key)?.target as? InMemoryDataProviderRepository<T>

            if let cached {
                return cached
            } else {
                let repository = InMemoryDataProviderRepository<T>()
                let weakWrapped = WeakWrapper(target: repository)

                cache.store(value: weakWrapped, for: key)

                return repository
            }
        case .ignoreCache:
            return InMemoryDataProviderRepository<T>()
        }
    }
}

private enum Constants {
    static var inMemoryRepositoriesKey: String = "io.novafoundation.novawallet.inmemory.repositories.cache"
}
