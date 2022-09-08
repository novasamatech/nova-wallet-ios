import Foundation
import RobinHood
import SubstrateSdk

protocol RemoteStorageRequestProtocol {
    var storagePath: StorageCodingPath { get }

    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data>
}

struct UnkeyedRemoteStorageRequest: RemoteStorageRequestProtocol {
    let storagePath: StorageCodingPath

    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data> {
        let operation = UnkeyedEncodingOperation(path: storagePath, storageKeyFactory: storageKeyFactory)
        operation.configurationBlock = {
            do {
                operation.codingFactory = try codingFactoryClosure()
            } catch {
                operation.result = .failure(error)
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}

struct MapRemoteStorageRequest<T: Encodable>: RemoteStorageRequestProtocol {
    let storagePath: StorageCodingPath
    let keyParamClosure: () throws -> T

    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data> {
        let encodingOperation = MapKeyEncodingOperation<T>(path: storagePath, storageKeyFactory: storageKeyFactory)
        encodingOperation.configurationBlock = {
            do {
                let keyParam = try keyParamClosure()
                encodingOperation.keyParams = [keyParam]

                encodingOperation.codingFactory = try codingFactoryClosure()
            } catch {
                encodingOperation.result = .failure(error)
            }
        }

        let mappingOperation = ClosureOperation<Data> {
            guard let remoteKey = try encodingOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return remoteKey
        }

        mappingOperation.addDependency(encodingOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [encodingOperation])
    }
}

struct DoubleMapRemoteStorageRequest<T1: Encodable, T2: Encodable>: RemoteStorageRequestProtocol {
    let storagePath: StorageCodingPath
    let keyParamClosure: () throws -> (T1, T2)
    let param1Encoder: ((T1) throws -> Data)?
    let param2Encoder: ((T2) throws -> Data)?

    func createKeyEncodingWrapper(
        using storageKeyFactory: StorageKeyFactoryProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<Data> {
        let encodingOperation = DoubleMapKeyEncodingOperation<T1, T2>(
            path: storagePath,
            storageKeyFactory: storageKeyFactory,
            param1Encoder: param1Encoder,
            param2Encoder: param2Encoder
        )

        encodingOperation.configurationBlock = {
            do {
                let keyParams = try keyParamClosure()
                encodingOperation.keyParams1 = [keyParams.0]
                encodingOperation.keyParams2 = [keyParams.1]

                encodingOperation.codingFactory = try codingFactoryClosure()
            } catch {
                encodingOperation.result = .failure(error)
            }
        }

        let mappingOperation = ClosureOperation<Data> {
            guard let remoteKey = try encodingOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return remoteKey
        }

        mappingOperation.addDependency(encodingOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [encodingOperation])
    }
}
