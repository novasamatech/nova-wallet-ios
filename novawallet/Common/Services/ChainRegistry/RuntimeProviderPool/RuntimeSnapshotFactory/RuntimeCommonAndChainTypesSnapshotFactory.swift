import Foundation
import Operation_iOS

final class RuntimeCommonAndChainTypesSnapshotFactory {
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

extension RuntimeCommonAndChainTypesSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let baseTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chain.chainId)

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chain.chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let maybeCommonTypes = try baseTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            let maybeChainTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            guard let commonTypes = maybeCommonTypes, let chainTypes = maybeChainTypes else {
                return nil
            }

            let info = try self.runtimeTypeRegistryFactory.createForCommonAndChainTypes(
                chain: chain,
                runtimeMetadataItem: runtimeMetadataItem,
                commonTypes: commonTypes,
                chainTypes: chainTypes
            )

            return RuntimeSnapshot(
                localCommonHash: commonTypes.sha256().toHex(),
                localChainHash: chainTypes.sha256().toHex(),
                typeRegistryCatalog: info.typeRegistryCatalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: info.runtimeMetadata
            )
        }

        let dependencies = baseTypesFetchOperation.allOperations + chainTypesFetchOperation.allOperations +
            [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}
