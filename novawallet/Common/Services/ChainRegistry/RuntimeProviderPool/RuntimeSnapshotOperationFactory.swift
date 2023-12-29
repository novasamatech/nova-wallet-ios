import Foundation
import SubstrateSdk
import RobinHood

protocol RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for chain: RuntimeProviderChain
    ) -> CompoundOperationWrapper<RuntimeSnapshot?>
}

enum RuntimeSnapshotFactoryError: Error {
    case unsupportedRuntimeVersion
}

final class RuntimeSnapshotFactory {
    let chainId: ChainModel.Id
    let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    let repository: AnyDataProviderRepository<RuntimeMetadataItem>
    let logger: LoggerProtocol

    init(
        chainId: ChainModel.Id,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        logger: LoggerProtocol
    ) {
        self.chainId = chainId
        self.filesOperationFactory = filesOperationFactory
        self.repository = repository
        self.logger = logger
    }

    private func createWrapperForCommonAndChainTypes() -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let baseTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let maybeCommonTypes = try baseTypesFetchOperation.targetOperation.extractNoCancellableResultData()
            let maybeChainTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadataContainer = try RuntimeMetadataContainer(scaleDecoder: decoder)

            guard let commonTypes = maybeCommonTypes, let chainTypes = maybeChainTypes else {
                return nil
            }

            let runtimeMetadata: RuntimeMetadataProtocol
            let catalog: TypeRegistryCatalogProtocol

            switch runtimeMetadataContainer.runtimeMetadata {
            case let .v13(metadata):
                catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                    commonTypes,
                    versioningData: chainTypes,
                    runtimeMetadata: metadata,
                    customExtensions: DefaultExtrinsicExtension.getCoders(for: metadata)
                )
                runtimeMetadata = metadata
            case let .v14(metadata):
                catalog = try TypeRegistryCatalog.createFromSiDefinition(
                    versioningData: chainTypes,
                    runtimeMetadata: metadata,
                    customExtensions: DefaultExtrinsicExtension.getCoders(for: metadata),
                    customTypeMapper: CustomSiMappers.all,
                    customNameMapper: ScaleInfoCamelCaseMapper()
                )
                runtimeMetadata = metadata
            }

            return RuntimeSnapshot(
                localCommonHash: commonTypes.sha256().toHex(),
                localChainHash: chainTypes.sha256().toHex(),
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = baseTypesFetchOperation.allOperations + chainTypesFetchOperation.allOperations +
            [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }

    private func createWrapperForCommonTypes() -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let commonTypesFetchOperation = filesOperationFactory.fetchCommonTypesOperation()

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let maybeCommonTypes = try commonTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadataContainer = try RuntimeMetadataContainer(scaleDecoder: decoder)

            guard let commonTypes = maybeCommonTypes else {
                return nil
            }

            let runtimeMetadata: RuntimeMetadataProtocol
            let catalog: TypeRegistryCatalogProtocol

            switch runtimeMetadataContainer.runtimeMetadata {
            case let .v13(metadata):
                catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                    commonTypes,
                    runtimeMetadata: metadata,
                    customExtensions: DefaultExtrinsicExtension.getCoders(for: metadata)
                )
                runtimeMetadata = metadata
            case let .v14(metadata):
                catalog = try TypeRegistryCatalog.createFromSiDefinition(
                    versioningData: commonTypes,
                    runtimeMetadata: metadata,
                    customExtensions: DefaultExtrinsicExtension.getCoders(for: metadata),
                    customTypeMapper: CustomSiMappers.all,
                    customNameMapper: ScaleInfoCamelCaseMapper()
                )
                runtimeMetadata = metadata
            }

            return RuntimeSnapshot(
                localCommonHash: commonTypes.sha256().toHex(),
                localChainHash: nil,
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = commonTypesFetchOperation.allOperations + [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }

    private func createWrapperForChainTypes() -> CompoundOperationWrapper<RuntimeSnapshot?> {
        let chainTypesFetchOperation = filesOperationFactory.fetchChainTypesOperation(for: chainId)

        let runtimeMetadataOperation = repository.fetchOperation(
            by: chainId,
            options: RepositoryFetchOptions()
        )

        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let maybeOwnTypes = try chainTypesFetchOperation.targetOperation.extractNoCancellableResultData()

            guard let runtimeMetadataItem = try runtimeMetadataOperation
                .extractNoCancellableResultData() else {
                return nil
            }

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadataContainer = try RuntimeMetadataContainer(scaleDecoder: decoder)

            guard let ownTypes = maybeOwnTypes else {
                return nil
            }

            let runtimeMetadata: RuntimeMetadataProtocol
            let catalog: TypeRegistryCatalogProtocol

            switch runtimeMetadataContainer.runtimeMetadata {
            case let .v13(metadata):
                catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                    ownTypes,
                    runtimeMetadata: metadata,
                    customExtensions: DefaultExtrinsicExtension.getCoders(for: metadata)
                )
                runtimeMetadata = metadata
            case let .v14(metadata):
                catalog = try TypeRegistryCatalog.createFromSiDefinition(
                    versioningData: ownTypes,
                    runtimeMetadata: metadata,
                    customExtensions: DefaultExtrinsicExtension.getCoders(for: metadata),
                    customTypeMapper: CustomSiMappers.all,
                    customNameMapper: ScaleInfoCamelCaseMapper()
                )
                runtimeMetadata = metadata
            }

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainHash: ownTypes.sha256().toHex(),
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        let dependencies = chainTypesFetchOperation.allOperations + [runtimeMetadataOperation]

        dependencies.forEach { snapshotOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: snapshotOperation, dependencies: dependencies)
    }

    func createWrapperForMetadataAndDefaultTyping(
        for chain: RuntimeProviderChain,
        logger: LoggerProtocol
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

            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadataContainer = try RuntimeMetadataContainer(scaleDecoder: decoder)

            let runtimeMetadata: RuntimeMetadataProtocol
            let catalog: TypeRegistryCatalogProtocol

            switch runtimeMetadataContainer.runtimeMetadata {
            case let .v14(metadata):
                let augmentationFactory = RuntimeAugmentationFactory()

                let result = !chain.isEthereumBased ? augmentationFactory.createSubstrateAugmentation(for: metadata) :
                    augmentationFactory.createEthereumBasedAugmentation(for: metadata)

                catalog = try TypeRegistryCatalog.createFromSiDefinition(
                    runtimeMetadata: metadata,
                    additionalNodes: result.additionalNodes.nodes,
                    customExtensions: DefaultExtrinsicExtension.getCoders(for: metadata),
                    customTypeMapper: CustomSiMappers.all,
                    customNameMapper: ScaleInfoCamelCaseMapper()
                )
                runtimeMetadata = metadata

                if !result.additionalNodes.notMatch.isEmpty {
                    logger.warning("No \(chain.name) type matching: \(result.additionalNodes.notMatch)")
                } else {
                    logger.debug("Types matching succeed for \(chain.name)")
                }
            case .v13:
                throw RuntimeSnapshotFactoryError.unsupportedRuntimeVersion
            }

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainHash: nil,
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
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
            return createWrapperForCommonTypes()
        case .onlyOwn:
            return createWrapperForChainTypes()
        case .both:
            return createWrapperForCommonAndChainTypes()
        case .none:
            return createWrapperForMetadataAndDefaultTyping(for: chain, logger: logger)
        }
    }
}
