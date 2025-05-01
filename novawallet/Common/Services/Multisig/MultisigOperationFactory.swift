import SubstrateSdk
import Operation_iOS

protocol MultisigStorageOperationFactoryProtocol {
    func fetchMultisigStateWrapper(
        for accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<AccountMultisigs?>
}

typealias AccountMultisigs = (accountId: AccountId, multisigs: [MultisigModel])

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
    ) -> CompoundOperationWrapper<AccountMultisigs?> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        
        let wrapper: CompoundOperationWrapper<[StorageResponse<[Multisig.MultisigOperation]>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [BytesCodable(wrappedValue: accountId)] },
            factory: { try codingFactoryOperation.extractNoCancellableResultData() },
            storagePath: Multisig.multisigList
        )
        
        wrapper.addDependency(operations: [codingFactoryOperation])
        
        let mapOperation = ClosureOperation<AccountMultisigs?> {
            let result = try wrapper.targetOperation.extractNoCancellableResultData()
            
            guard let values = result.first?.value else { return nil }
            
            let multisigs = values.map { value in
                let timepoint = MultisigModel.Timepoint(
                    height: value.timepoint.height,
                    index: value.timepoint.index
                )
                let multisig = MultisigModel(
                    signatory: value.depositor,
                    signatories: value.approvals.map { $0.wrappedValue },
                    timepoint: timepoint,
                    status: .pending
                )
                
                return multisig
            }
            
            return (accountId, multisigs)
        }
        
        mapOperation.addDependency(wrapper.targetOperation)
        
        let dependencies = [codingFactoryOperation] + wrapper.allOperations
        
        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
