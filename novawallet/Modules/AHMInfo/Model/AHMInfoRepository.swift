import Foundation
import Operation_iOS

protocol AHMInfoRepositoryProtocol {
    func fetchAllWrapper() -> CompoundOperationWrapper<[AHMRemoteData]>
    func fetch(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMRemoteData?>
}

final class AHMInfoRepository {
    private let cache: ExpiringInMemoryCache<ChainModel.Id, AHMRemoteData>
    private let fetchOperationFactory: AHMInfoFetchOperationFactoryProtocol
    private let ahmConfigsPath: String

    private let mutex = NSLock()

    init(
        cache: ExpiringInMemoryCache<ChainModel.Id, AHMRemoteData> = .init(expirationPeriod: .day),
        fetchOperationFactory: AHMInfoFetchOperationFactoryProtocol = AHMInfoFetchOperationFactory(),
        ahmConfigsPath: String = ApplicationConfig.shared.assetHubMigrationConfigsPath
    ) {
        self.cache = cache
        self.fetchOperationFactory = fetchOperationFactory
        self.ahmConfigsPath = ahmConfigsPath
    }
}

// MARK: - Private

private extension AHMInfoRepository {
    func createFetchWrapper(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMRemoteData?> {
        let fetchAllWrapper = createFetchAllWrapper()

        let mapOperation: BaseOperation<AHMRemoteData?> = ClosureOperation {
            let ahmConfigs = try fetchAllWrapper.targetOperation.extractNoCancellableResultData()

            return ahmConfigs.first { $0.sourceData.chainId == chainId }
        }

        mapOperation.addDependency(fetchAllWrapper.targetOperation)

        return fetchAllWrapper.insertingTail(operation: mapOperation)
    }

    func createFetchAllWrapper() -> CompoundOperationWrapper<[AHMRemoteData]> {
        let fetchOperation = fetchOperationFactory.fetchOperation()
        let cacheUpdateOperation = createCacheUpdateOperation(dependingOn: fetchOperation)

        cacheUpdateOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: cacheUpdateOperation,
            dependencies: [fetchOperation]
        )
    }

    func createCacheUpdateOperation(
        dependingOn fetchOperation: BaseOperation<[AHMRemoteData]>
    ) -> BaseOperation<[AHMRemoteData]> {
        ClosureOperation { [weak self] in
            let ahmConfigs = try fetchOperation.extractNoCancellableResultData()

            self?.mutex.lock()

            ahmConfigs.forEach {
                self?.cache.store(
                    value: $0,
                    for: $0.sourceData.chainId
                )
            }

            self?.mutex.unlock()

            return ahmConfigs
        }
    }
}

// MARK: - AHMInfoRepositoryProtocol

extension AHMInfoRepository: AHMInfoRepositoryProtocol {
    func fetchAllWrapper() -> CompoundOperationWrapper<[AHMRemoteData]> {
        let cachedValues = cache.fetchAllValues()

        guard cachedValues.isEmpty else {
            return .createWithResult(cachedValues)
        }

        return createFetchAllWrapper()
    }

    func fetch(by chainId: ChainModel.Id) -> CompoundOperationWrapper<AHMRemoteData?> {
        let cachedValue = cache.fetchValue(for: chainId)

        guard cachedValue == nil else {
            return .createWithResult(cachedValue)
        }

        return createFetchWrapper(by: chainId)
    }
}

// MARK: - Shared

extension AHMInfoRepository {
    static let shared = AHMInfoRepository()
}
