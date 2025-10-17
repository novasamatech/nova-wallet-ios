import SubstrateSdk
import Operation_iOS
import Foundation

protocol MultisigStorageOperationFactoryProtocol {
    func fetchPendingOperations(
        for multisigAccountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Substrate.CallHash: MultisigPallet.MultisigDefinition]>

    func fetchPendingOperation(
        for multisigAccountId: AccountId,
        callHashClosure: @escaping () throws -> Substrate.CallHash,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<MultisigPallet.MultisigDefinition?>
}

final class MultisigStorageOperationFactory {
    private let storageRequestFactory: StorageRequestFactoryProtocol

    init(storageRequestFactory: StorageRequestFactoryProtocol) {
        self.storageRequestFactory = storageRequestFactory
    }

    init(operationQueue: OperationQueue) {
        storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
    }
}

extension MultisigStorageOperationFactory: MultisigStorageOperationFactoryProtocol {
    func fetchPendingOperations(
        for multisigAccountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Substrate.CallHash: MultisigPallet.MultisigDefinition]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let request = MapRemoteStorageRequest(storagePath: MultisigPallet.multisigListStoragePath) {
            BytesCodable(wrappedValue: multisigAccountId)
        }
        let wrapper: CompoundOperationWrapper<[MultisigPallet.CallHashKey: MultisigPallet.MultisigDefinition]>
        wrapper = storageRequestFactory.queryByPrefix(
            engine: connection,
            request: request,
            storagePath: MultisigPallet.multisigListStoragePath,
            factory: { try codingFactoryOperation.extractNoCancellableResultData() }
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<[Substrate.CallHash: MultisigPallet.MultisigDefinition]> {
            try wrapper
                .targetOperation
                .extractNoCancellableResultData()
                .reduce(into: [:]) { $0[$1.key.callHash] = $1.value }
        }

        mapOperation.addDependency(wrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }

    func fetchPendingOperation(
        for multisigAccountId: AccountId,
        callHashClosure: @escaping () throws -> Substrate.CallHash,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<MultisigPallet.MultisigDefinition?> {
        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<MultisigPallet.MultisigDefinition>]>
        wrapper = storageRequestFactory.queryItems(
            engine: connection,
            keyParams1: {
                [multisigAccountId]
            },
            keyParams2: {
                let callHash = try callHashClosure()
                return [callHash]
            },
            factory: {
                try coderFactoryOperation.extractNoCancellableResultData()
            },
            storagePath: MultisigPallet.multisigListStoragePath
        )

        wrapper.addDependency(operations: [coderFactoryOperation])

        let mappingOperation = ClosureOperation<MultisigPallet.MultisigDefinition?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        mappingOperation.addDependency(wrapper.targetOperation)

        return wrapper
            .insertingHead(operations: [coderFactoryOperation])
            .insertingTail(operation: mappingOperation)
    }
}
