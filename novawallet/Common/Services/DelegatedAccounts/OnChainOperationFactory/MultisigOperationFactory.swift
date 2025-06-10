import SubstrateSdk
import Operation_iOS

protocol MultisigStorageOperationFactoryProtocol {
    func fetchPendingOperations(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[CallHash]>
}

typealias OnChainMultisigs = (accountId: AccountId, multisigs: [Multisig.MultisigOperation])

final class MultisigStorageOperationFactory {
    private let storageRequestFactory: StorageRequestFactoryProtocol

    init(storageRequestFactory: StorageRequestFactoryProtocol) {
        self.storageRequestFactory = storageRequestFactory
    }
}

extension MultisigStorageOperationFactory: MultisigStorageOperationFactoryProtocol {
    func fetchPendingOperations(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[CallHash]> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<Multisig.MultisigOperation>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: accountId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Multisig.multisigList
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<[CallHash]> {
            try wrapper
                .targetOperation
                .extractNoCancellableResultData()
                .compactMap(\.key)
        }

        mapOperation.addDependency(wrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
