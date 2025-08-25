import Foundation
import Operation_iOS

final class RuntimeDefaultTypesSnapshotFactory {
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol

    init(
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
    ) {
        self.repository = repository
        self.runtimeTypeRegistryFactory = runtimeTypeRegistryFactory
    }
}

extension RuntimeDefaultTypesSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let runtimeMetadataOperation = repository.fetchOperation(
            by: chain.chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let info = try self.runtimeTypeRegistryFactory.createForMetadataAndDefaultTyping(
                chain: chain,
                runtimeMetadataItem: runtimeMetadataItem
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainHash: nil,
                typeRegistryCatalog: info.typeRegistryCatalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: info.runtimeMetadata
            )
        }

        let dependencies = [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}
