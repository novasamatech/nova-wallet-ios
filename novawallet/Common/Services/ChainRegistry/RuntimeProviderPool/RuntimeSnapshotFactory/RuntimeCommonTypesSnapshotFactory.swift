import Foundation
import Operation_iOS

final class RuntimeCommonTypesSnapshotFactory {
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

extension RuntimeCommonTypesSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let commonTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chain.chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let maybeCommonTypes = try commonTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            guard let commonTypes = maybeCommonTypes else {
                return nil
            }

            let info = try self.runtimeTypeRegistryFactory.createForCommonTypes(
                chain: chain,
                runtimeMetadataItem: runtimeMetadataItem,
                commonTypes: commonTypes
            )

            return RuntimeSnapshot(
                localCommonHash: commonTypes.sha256().toHex(),
                localChainHash: nil,
                typeRegistryCatalog: info.typeRegistryCatalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: info.runtimeMetadata
            )
        }

        let dependencies = commonTypesFetchOperation.allOperations + [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }
}
