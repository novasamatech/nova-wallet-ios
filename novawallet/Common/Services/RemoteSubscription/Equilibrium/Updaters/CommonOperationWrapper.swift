import Foundation
import Operation_iOS

enum CommonOperationWrapper {
    static func storageDecoderWrapper<T: Decodable>(
        for value: Data?,
        path: StorageCodingPath,
        chainModelId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol
    ) -> CompoundOperationWrapper<T?> {
        guard let storageData = value else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainModelId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let decodingOperation = StorageDecodingOperation<T>(path: path, data: storageData)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<T?> {
            try decodingOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, decodingOperation]
        )
    }

    static func storageDecoderListWrapper<T: Decodable>(
        for value: [Data?],
        path: StorageCodingPath,
        chainModelId: ChainModel.Id,
        chainRegistry: ChainRegistryProtocol
    ) -> CompoundOperationWrapper<[T?]> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainModelId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let decodingOperation = StorageDecodingOptionalListOperation<T>(path: path, dataList: value)

        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let mappingOperation = ClosureOperation<[T?]> {
            try decodingOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, decodingOperation]
        )
    }
}
