import Foundation
import RobinHood
import SubstrateSdk

struct LocalStorageResponse<T: Decodable> {
    let key: String
    let data: Data?
    let value: T?
}

protocol LocalStorageRequestFactoryProtocol {
    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        key: @escaping () throws -> String,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where T: Decodable
}

final class LocalStorageRequestFactory: LocalStorageRequestFactoryProtocol {
    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        key: @escaping () throws -> String,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<LocalStorageResponse<T>> where T: Decodable {
        let queryOperation = repository.fetchOperation(by: key, options: RepositoryFetchOptions())

        let decodingOperation = StorageDecodingListOperation<T>(path: params.path)
        decodingOperation.configurationBlock = {
            do {
                let result = try queryOperation.extractNoCancellableResultData()

                decodingOperation.codingFactory = try factory()

                decodingOperation.dataList = result.map { [$0.data] } ?? []
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(queryOperation)

        let mapOperation = ClosureOperation<LocalStorageResponse<T>> {
            let fetchResult = try queryOperation.extractNoCancellableResultData()
            let decodedResult = try decodingOperation.extractNoCancellableResultData().first
            let key = try key()

            return LocalStorageResponse(key: key, data: fetchResult?.data, value: decodedResult)
        }

        mapOperation.addDependency(decodingOperation)

        let dependencies = [queryOperation, decodingOperation]

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}

extension LocalStorageRequestFactoryProtocol {
    func queryItems<T>(
        repository: AnyDataProviderRepository<ChainStorageItem>,
        key: @escaping () throws -> String,
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        params: StorageRequestParams
    ) -> CompoundOperationWrapper<T?> where T: Decodable {
        let wrapper: CompoundOperationWrapper<LocalStorageResponse<T>> =
            queryItems(repository: repository, key: key, factory: factory, params: params)

        let mapOperation = ClosureOperation<T?> {
            try wrapper.targetOperation.extractNoCancellableResultData().value
        }

        wrapper.allOperations.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)
    }
}
