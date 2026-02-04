import Foundation
import Operation_iOS

protocol ASMInfoRepositoryProtocol {
    func fetchWrapper() -> CompoundOperationWrapper<ASMRemoteData?>
}

final class ASMInfoRepository {
    private let cache: ExpiringInMemoryCache<String, ASMRemoteData>
    private let fetchOperationFactory: ASMInfoFetchOperationFactoryProtocol

    private let mutex = NSLock()

    init(
        cache: ExpiringInMemoryCache<String, ASMRemoteData> = .init(expirationPeriod: .day),
        fetchOperationFactory: ASMInfoFetchOperationFactoryProtocol = ASMInfoFetchOperationFactory()
    ) {
        self.cache = cache
        self.fetchOperationFactory = fetchOperationFactory
    }
}

// MARK: - Private

private extension ASMInfoRepository {
    func createFetchWrapper() -> CompoundOperationWrapper<ASMRemoteData?> {
        let fetchOperation = fetchOperationFactory.fetchOperation()
        let cacheUpdateOperation = createCacheUpdateOperation(dependingOn: fetchOperation)

        cacheUpdateOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: cacheUpdateOperation,
            dependencies: [fetchOperation]
        )
    }

    func createCacheUpdateOperation(
        dependingOn fetchOperation: BaseOperation<ASMRemoteData?>
    ) -> BaseOperation<ASMRemoteData?> {
        ClosureOperation { [weak self] in
            let asmConfig = try fetchOperation.extractNoCancellableResultData()

            if let config = asmConfig {
                self?.mutex.lock()
                self?.cache.store(value: config, for: config.cacheKey)
                self?.mutex.unlock()
            }

            return asmConfig
        }
    }
}

// MARK: - ASMInfoRepositoryProtocol

extension ASMInfoRepository: ASMInfoRepositoryProtocol {
    func fetchWrapper() -> CompoundOperationWrapper<ASMRemoteData?> {
        let cachedValues = cache.fetchAllValues()

        guard cachedValues.isEmpty else {
            return .createWithResult(cachedValues.first)
        }

        return createFetchWrapper()
    }
}

// MARK: - Shared

extension ASMInfoRepository {
    static let shared = ASMInfoRepository()
}
