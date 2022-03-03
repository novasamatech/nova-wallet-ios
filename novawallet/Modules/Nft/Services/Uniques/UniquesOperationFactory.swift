import Foundation
import RobinHood
import SubstrateSdk

protocol UniquesOperationFactoryProtocol {
    func createAccountKeysWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UniquesAccountKey]>

    func createClassMetadataWrapper(
        for classIdsClosure: @escaping () throws -> [UInt32],
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UInt32: UniquesClassMetadata]>

    func createInstanceMetadataWrapper(
        for classIdsClosure: @escaping () throws -> [UInt32],
        instanceIdsClosure: @escaping () throws -> [UInt32],
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UInt32: UniquesInstanceMetadata]>

    func createClassDetails(
        for classIdsClosure: @escaping () throws -> [UInt32],
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UInt32: UniquesClassDetails]>
}

final class UniquesOperationFactory: UniquesOperationFactoryProtocol {
    func createAccountKeysWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UniquesAccountKey]> {
        let keyEncodingOperation = MapKeyEncodingOperation(
            path: .uniquesAccount,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: [accountId]
        )

        keyEncodingOperation.configurationBlock = {
            do {
                keyEncodingOperation.codingFactory = try codingFactoryClosure()
            } catch {
                keyEncodingOperation.result = .failure(error)
            }
        }

        let keysFetchOperation = StorageKeysQueryService(
            connection: connection,
            operationManager: operationManager,
            prefixKeyClosure: {
                guard
                    let prefix = try keyEncodingOperation.extractNoCancellableResultData().first else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                return prefix
            },
            mapper: AnyMapper(mapper: IdentityMapper())
        ).longrunOperation()

        keysFetchOperation.addDependency(keyEncodingOperation)

        let decodingOperation = StorageKeyDecodingOperation<UniquesAccountKey>(path: .uniquesAccount)
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryClosure()
                decodingOperation.dataList = try keysFetchOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(keysFetchOperation)

        let dependencies = [keyEncodingOperation, keysFetchOperation]

        return CompoundOperationWrapper(targetOperation: decodingOperation, dependencies: dependencies)
    }

    func createClassMetadataWrapper(
        for classIdsClosure: @escaping () throws -> [UInt32],
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UInt32: UniquesClassMetadata]> {
        let requestEngine = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let keyParams: () throws -> [StringScaleMapper<UInt32>] = {
            let classIds = try classIdsClosure()
            return classIds.map { StringScaleMapper(value: $0) }
        }

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<UniquesClassMetadata>]> =
            requestEngine.queryItems(
                engine: connection,
                keyParams: keyParams,
                factory: codingFactoryClosure,
                storagePath: .uniquesClassMetadata
            )

        let mapOperation = ClosureOperation<[UInt32: UniquesClassMetadata]> {
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            let classIds = try classIdsClosure()

            let initialStorage = [UInt32: UniquesClassMetadata]()
            return responses.enumerated().reduce(into: initialStorage) { result, item in
                guard let value = item.element.value else {
                    return
                }

                let classId = classIds[item.offset]

                result[classId] = value
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        let dependencies = fetchWrapper.allOperations
        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createInstanceMetadataWrapper(
        for classIdsClosure: @escaping () throws -> [UInt32],
        instanceIdsClosure: @escaping () throws -> [UInt32],
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UInt32: UniquesInstanceMetadata]> {
        let requestEngine = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let keyParams1: () throws -> [StringScaleMapper<UInt32>] = {
            let classIds = try classIdsClosure()
            return classIds.map { StringScaleMapper(value: $0) }
        }

        let keyParams2: () throws -> [StringScaleMapper<UInt32>] = {
            let instanceIds = try instanceIdsClosure()
            return instanceIds.map { StringScaleMapper(value: $0) }
        }

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<UniquesInstanceMetadata>]> =
            requestEngine.queryItems(
                engine: connection,
                keyParams1: keyParams1,
                keyParams2: keyParams2,
                factory: { try codingFactoryClosure() },
                storagePath: .uniquesInstanceMetadata
            )

        let mapOperation = ClosureOperation<[UInt32: UniquesInstanceMetadata]> {
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            let instanceIds = try instanceIdsClosure()

            let initialStorage = [UInt32: UniquesInstanceMetadata]()
            return responses.enumerated().reduce(into: initialStorage) { result, item in
                guard let value = item.element.value else {
                    return
                }

                let instanceId = instanceIds[item.offset]

                result[instanceId] = value
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        let dependencies = fetchWrapper.allOperations
        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createClassDetails(
        for classIdsClosure: @escaping () throws -> [UInt32],
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        codingFactoryClosure: @escaping () throws -> RuntimeCoderFactoryProtocol
    ) -> CompoundOperationWrapper<[UInt32: UniquesClassDetails]> {
        let requestEngine = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let keyParams: () throws -> [StringScaleMapper<UInt32>] = {
            let classIds = try classIdsClosure()
            return classIds.map { StringScaleMapper(value: $0) }
        }

        let fetchWrapper: CompoundOperationWrapper<[StorageResponse<UniquesClassDetails>]> =
            requestEngine.queryItems(
                engine: connection,
                keyParams: keyParams,
                factory: codingFactoryClosure,
                storagePath: .uniquesClassDetails
            )

        let mapOperation = ClosureOperation<[UInt32: UniquesClassDetails]> {
            let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()
            let classIds = try classIdsClosure()

            let initialStorage = [UInt32: UniquesClassDetails]()
            return responses.enumerated().reduce(into: initialStorage) { result, item in
                guard let value = item.element.value else {
                    return
                }

                let classId = classIds[item.offset]

                result[classId] = value
            }
        }

        mapOperation.addDependency(fetchWrapper.targetOperation)

        let dependencies = fetchWrapper.allOperations
        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
