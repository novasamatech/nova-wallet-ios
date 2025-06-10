import SubstrateSdk
import Operation_iOS

protocol MultisigStorageOperationFactoryProtocol {
    func fetchPendingOperations(
        for multisigAccountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[CallHash: Multisig.MultisigDefinition]>
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
    ) -> CompoundOperationWrapper<[CallHash: Multisig.MultisigDefinition]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<Multisig.MultisigDefinition>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: multisigAccountId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Multisig.multisigList
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<[CallHash: Multisig.MultisigDefinition]> {
            try wrapper
                .targetOperation
                .extractNoCancellableResultData()
                .reduce(into: [:]) { $0[$1.key] = $1.value }
        }

        mapOperation.addDependency(wrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
