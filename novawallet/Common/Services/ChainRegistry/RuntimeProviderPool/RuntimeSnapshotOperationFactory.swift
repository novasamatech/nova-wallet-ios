import Foundation
import SubstrateSdk
import Operation_iOS

protocol RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?>
}

final class RuntimeSnapshotFactory {
    let chainId: ChainModel.Id
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol

    init(
        chainId: ChainModel.Id,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
    ) {
        self.chainId = chainId
        self.filesOperationFactory = filesOperationFactory
        self.repository = repository
        self.runtimeTypeRegistryFactory = runtimeTypeRegistryFactory
    }

    private func createWrapperForCommonAndChainTypes(
        for chain: RuntimeProviderChain,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
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

            let info = try runtimeTypeRegistryFactory.createForCommonAndChainTypes(
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

    private func createWrapperForCommonTypes(
        for chain: RuntimeProviderChain,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
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

            let info = try runtimeTypeRegistryFactory.createForCommonTypes(
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

    private func createWrapperForChainTypes(
        for chain: RuntimeProviderChain,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
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

            let info = try runtimeTypeRegistryFactory.createForChainTypes(
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

    func createWrapperForMetadataAndDefaultTyping(
        for chain: RuntimeProviderChain,
        runtimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let runtimeMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let info = try runtimeTypeRegistryFactory.createForMetadataAndDefaultTyping(
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

extension RuntimeSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?> {
        switch chain.typesUsage {
        case .onlyCommon:
            return createWrapperForCommonTypes(
                for: chain,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory
            )
        case .onlyOwn:
            return createWrapperForChainTypes(
                for: chain,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory
            )
        case .both:
            return createWrapperForCommonAndChainTypes(
                for: chain,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory
            )
        case .none:
            return createWrapperForMetadataAndDefaultTyping(
                for: chain,
                runtimeTypeRegistryFactory: runtimeTypeRegistryFactory
            )
        }
    }
}
