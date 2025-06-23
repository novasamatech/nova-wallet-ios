import SubstrateSdk
import Operation_iOS

protocol MultisigStorageOperationFactoryProtocol {
    func fetchPendingOperations(
        for multisigAccountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[CallHash: MultisigPallet.MultisigDefinition]>
}

final class MultisigStorageOperationFactory {
    private let storageRequestFactory: StorageRequestFactoryProtocol

    init(storageRequestFactory: StorageRequestFactoryProtocol) {
        self.storageRequestFactory = storageRequestFactory
    }
}

extension MultisigStorageOperationFactory: MultisigStorageOperationFactoryProtocol {
    func fetchPendingOperations(
        for multisigAccountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[CallHash: MultisigPallet.MultisigDefinition]> {
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

        let mapOperation = ClosureOperation<[CallHash: MultisigPallet.MultisigDefinition]> {
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
}
