import SubstrateSdk
import Operation_iOS

protocol MultisigStorageOperationFactoryProtocol {
    func fetchMultisigStateWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<OnChainMultisigs?>
}

typealias OnChainMultisigs = (accountId: AccountId, multisigs: [Multisig.MultisigOperation])

final class MultisigStorageOperationFactory {
    private let storageRequestFactory: StorageRequestFactoryProtocol

    init(storageRequestFactory: StorageRequestFactoryProtocol) {
        self.storageRequestFactory = storageRequestFactory
    }
}

extension MultisigStorageOperationFactory: MultisigStorageOperationFactoryProtocol {
    func fetchMultisigStateWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<OnChainMultisigs?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<[Multisig.MultisigOperation]>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: accountId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Multisig.multisigList
        )

        wrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<OnChainMultisigs?> {
            let result = try wrapper.targetOperation.extractNoCancellableResultData()

            guard let values = result.first?.value else { return nil }

            return (accountId, values.compactMap { $0 })
        }

        mapOperation.addDependency(wrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + wrapper.allOperations

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
