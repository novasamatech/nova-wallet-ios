import Foundation
import Operation_iOS
import SubstrateSdk

enum SubtensorChunkedStorageQueryError: Error {
    case missingStorageItem(StorageCodingPath)
}

final class SubtensorChunkedStorageQueryFactory {
    struct Context {
        let engine: JSONRPCEngine
        let codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
        let blockHashOperation: BaseOperation<BlockHashData>?
    }

    let keysPerQuery: Int
    let timeout: Int

    private let storageKeyFactory: StorageKeyFactoryProtocol = StorageKeyFactory()

    init(keysPerQuery: Int, timeout: Int) {
        self.keysPerQuery = keysPerQuery
        self.timeout = timeout
    }

    static func distinct<T: Hashable>(_ items: [T]) -> [T] {
        var seen = Set<T>()

        return items.filter { seen.insert($0).inserted }
    }

    func createPlainKeyOperation(path: StorageCodingPath) throws -> BaseOperation<[Data]> {
        let key = try storageKeyFactory.createStorageKey(moduleName: path.moduleName, storageName: path.itemName)

        return ClosureOperation { [key] }
    }

    func createKeysOperation<K: Encodable>(
        path: StorageCodingPath,
        params: [K],
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<[Data]> {
        let operation = MapKeyEncodingOperation<K>(path: path, storageKeyFactory: storageKeyFactory, keyParams: params)

        operation.configurationBlock = {
            do {
                operation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        operation.addDependency(codingFactoryOperation)

        return operation
    }

    func createKeysOperation<K: Encodable>(
        path: StorageCodingPath,
        paramsOperation: BaseOperation<[K]>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<[Data]> {
        let operation = MapKeyEncodingOperation<K>(path: path, storageKeyFactory: storageKeyFactory)

        operation.configurationBlock = {
            do {
                operation.keyParams = try paramsOperation.extractNoCancellableResultData()
                operation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        operation.addDependency(paramsOperation)
        operation.addDependency(codingFactoryOperation)

        return operation
    }

    func createKeysOperation<K1: Encodable, K2: Encodable>(
        path: StorageCodingPath,
        params1: [K1],
        params2: [K2],
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<[Data]> {
        let operation = DoubleMapKeyEncodingOperation<K1, K2>(
            path: path,
            storageKeyFactory: storageKeyFactory,
            keyParams1: params1,
            keyParams2: params2
        )

        operation.configurationBlock = {
            do {
                operation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                operation.result = .failure(error)
            }
        }

        operation.addDependency(codingFactoryOperation)

        return operation
    }

    func createQueryWrapper<T: Decodable>(
        path: StorageCodingPath,
        keysOperation: BaseOperation<[Data]>,
        maxKeyCount: Int,
        context: Context
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        let chunkCount = (maxKeyCount + keysPerQuery - 1) / keysPerQuery

        let queryOperations = (0 ..< chunkCount).map { chunkIndex in
            createChunkOperation(chunkIndex: chunkIndex, keysOperation: keysOperation, context: context)
        }

        let decodingOperation = StorageFallbackDecodingListOperation<T>(path: path)

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try context.codingFactoryOperation.extractNoCancellableResultData()
                decodingOperation.dataList = try Self.extractChanges(from: queryOperations).map(\.value)
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        queryOperations.forEach { decodingOperation.addDependency($0) }
        decodingOperation.addDependency(context.codingFactoryOperation)

        let mergeOperation = ClosureOperation<[StorageResponse<T>]> {
            let keys = try keysOperation.extractNoCancellableResultData()
            let changes = try Self.extractChanges(from: queryOperations)
            let values = try decodingOperation.extractNoCancellableResultData()

            let responses = zip(changes, values).reduce(into: [Data: StorageResponse<T>]()) { result, item in
                result[item.0.key] = StorageResponse(key: item.0.key, data: item.0.value, value: item.1)
            }

            return try keys.map { key in
                guard let response = responses[key] else {
                    throw SubtensorChunkedStorageQueryError.missingStorageItem(path)
                }

                return response
            }
        }

        mergeOperation.addDependency(keysOperation)
        mergeOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [keysOperation] + queryOperations + [decodingOperation]
        )
    }
}

private extension SubtensorChunkedStorageQueryFactory {
    static func extractChanges(
        from operations: [JSONRPCQueryOperation]
    ) throws -> [StorageUpdateData.StorageUpdateChangeData] {
        try operations
            .flatMap { try $0.extractNoCancellableResultData() }
            .flatMap { StorageUpdateData(update: $0).changes }
    }

    func createChunkOperation(
        chunkIndex: Int,
        keysOperation: BaseOperation<[Data]>,
        context: Context
    ) -> JSONRPCQueryOperation {
        let operation = JSONRPCQueryOperation(
            engine: context.engine,
            method: RPCMethod.queryStorageAt,
            timeout: timeout
        )

        let chunkSize = keysPerQuery

        operation.configurationBlock = {
            do {
                let keys = try keysOperation.extractNoCancellableResultData()
                let lowerBound = chunkIndex * chunkSize

                guard lowerBound < keys.count else {
                    operation.result = .success([])
                    return
                }

                let upperBound = min(lowerBound + chunkSize, keys.count)
                let blockHash = try context.blockHashOperation?.extractNoCancellableResultData()

                operation.parameters = StorageQuery(keys: Array(keys[lowerBound ..< upperBound]), blockHash: blockHash)
            } catch {
                operation.result = .failure(error)
            }
        }

        operation.addDependency(keysOperation)

        if let blockHashOperation = context.blockHashOperation {
            operation.addDependency(blockHashOperation)
        }

        return operation
    }
}
