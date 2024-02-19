import Foundation
import RobinHood
import SubstrateSdk

protocol StorageKeysOperationFactoryProtocol {
    func createKeysFetchWrapper<T: JSONListConvertible>(
        for keyPrefixRequest: RemoteStorageRequestProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[T]>
}

extension StorageKeysOperationFactoryProtocol {
    func createKeysFetchWrapper<T: JSONListConvertible>(
        by storagePath: StorageCodingPath,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[T]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: storagePath)

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let fetchWrapper: CompoundOperationWrapper<[T]> = createKeysFetchWrapper(
            for: request,
            codingFactoryClosure: { try codingFactoryOperation.extractNoCancellableResultData() },
            connection: connection
        )

        fetchWrapper.addDependency(operations: [codingFactoryOperation])

        return fetchWrapper.insertingHead(operations: [codingFactoryOperation])
    }

    func createKeysFetchWrapper<T: JSONListConvertible>(
        by storagePath: StorageCodingPath,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[T]> {
        let request = UnkeyedRemoteStorageRequest(storagePath: storagePath)

        return createKeysFetchWrapper(
            for: request,
            codingFactoryClosure: codingFactoryClosure,
            connection: connection
        )
    }
}

final class StorageKeysOperationFactory {
    let operationQueue: OperationQueue

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }
}

extension StorageKeysOperationFactory: StorageKeysOperationFactoryProtocol {
    func createKeysFetchWrapper<T: JSONListConvertible>(
        for keyPrefixRequest: RemoteStorageRequestProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<[T]> {
        let prefixEncodingWrapper = keyPrefixRequest.createKeyEncodingWrapper(
            using: StorageKeyFactory(),
            codingFactoryClosure: codingFactoryClosure
        )

        let keysFetchOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: OperationManager(operationQueue: operationQueue),
            prefixKeyClosure: { try prefixEncodingWrapper.targetOperation.extractNoCancellableResultData() },
            mapper: AnyMapper(mapper: IdentityMapper())
        ).longrunOperation()

        keysFetchOperation.addDependency(prefixEncodingWrapper.targetOperation)

        let decodingOperation = StorageKeyDecodingOperation<T>(
            path: keyPrefixRequest.storagePath
        )

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryClosure()
                decodingOperation.dataList = try keysFetchOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(keysFetchOperation)

        return CompoundOperationWrapper(
            targetOperation: decodingOperation,
            dependencies: prefixEncodingWrapper.allOperations + [keysFetchOperation]
        )
    }
}
