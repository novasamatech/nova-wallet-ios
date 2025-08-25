import Foundation
import Operation_iOS

final class RuntimeChainTypesSnapshotFactory {
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol

    init(
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    ) {
        self.repository = repository
        self.runtimeTypeRegistryFactory = runtimeTypeRegistryFactory
        self.filesOperationFactory = filesOperationFactory
    }
}

extension RuntimeChainTypesSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chain.chainId)

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chain.chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let maybeOwnTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            guard let ownTypes = maybeOwnTypes else {
                return nil
            }

            let info = try self.runtimeTypeRegistryFactory.createForChainTypes(
                chain: chain,
                runtimeMetadataItem: runtimeMetadataItem,
                chainTypes: ownTypes
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainHash: ownTypes.sha256().toHex(),
                typeRegistryCatalog: info.typeRegistryCatalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: info.runtimeMetadata
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations + [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}
