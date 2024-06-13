import Foundation
import SubstrateSdk

struct RuntimeTypeRegistryInfo {
    let runtimeMetadata: RuntimeMetadataProtocol
    let typeRegistryCatalog: TypeRegistryCatalogProtocol
}

enum RuntimeTypeRegistryFactoryError: Error {
    case unsupportedRuntimeVersion
}

protocol RuntimeTypeRegistryFactoryProtocol {
    func createForMetadataAndDefaultTyping(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem
    ) throws -> RuntimeTypeRegistryInfo

    func createForChainTypes(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem,
        chainTypes: Data
    ) throws -> RuntimeTypeRegistryInfo

    func createForCommonTypes(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem,
        commonTypes: Data
    ) throws -> RuntimeTypeRegistryInfo

    func createForCommonAndChainTypes(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem,
        commonTypes: Data,
        chainTypes: Data
    ) throws -> RuntimeTypeRegistryInfo
}

final class RuntimeTypeRegistryFactory: RuntimeTypeRegistryFactoryProtocol {
    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    private func createRuntimeContainer(
        from runtimeMetadataItem: RuntimeMetadataItem
    ) throws -> RuntimeMetadataContainer {
        if runtimeMetadataItem.opaque {
            return try RuntimeMetadataContainer.createFromOpaque(data: runtimeMetadataItem.metadata)
        } else {
            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            return try RuntimeMetadataContainer(scaleDecoder: decoder)
        }
    }

    private func createForPostV14MetadataAndDefaultTyping(
        _ post14Metadata: PostV14RuntimeMetadataProtocol,
        chain: RuntimeProviderChain
    ) throws -> RuntimeTypeRegistryInfo {
        let augmentationFactory = RuntimeAugmentationFactory()

        let result = !chain.isEthereumBased ? augmentationFactory.createSubstrateAugmentation(for: post14Metadata) :
            augmentationFactory.createEthereumBasedAugmentation(for: post14Metadata)

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId)

        let catalog = try TypeRegistryCatalog.createFromSiDefinition(
            runtimeMetadata: post14Metadata,
            additionalNodes: result.additionalNodes.nodes,
            customExtensions: signedExtensionFactory.createCoders(for: post14Metadata),
            customTypeMapper: CustomSiMappers.all,
            customNameMapper: ScaleInfoCamelCaseMapper()
        )

        if !result.additionalNodes.notMatch.isEmpty {
            logger.warning("No \(chain.name) type matching: \(result.additionalNodes.notMatch)")
        } else {
            logger.debug("Types matching succeed for \(chain.name)")
        }

        return RuntimeTypeRegistryInfo(runtimeMetadata: post14Metadata, typeRegistryCatalog: catalog)
    }
}

extension RuntimeTypeRegistryFactory {
    func createForMetadataAndDefaultTyping(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem
    ) throws -> RuntimeTypeRegistryInfo {
        let runtimeMetadataContainer = try createRuntimeContainer(from: runtimeMetadataItem)

        switch runtimeMetadataContainer.runtimeMetadata {
        case let .v14(metadata):
            return try createForPostV14MetadataAndDefaultTyping(metadata, chain: chain)
        case let .v15(metadata):
            return try createForPostV14MetadataAndDefaultTyping(metadata, chain: chain)
        case .v13:
            throw RuntimeTypeRegistryFactoryError.unsupportedRuntimeVersion
        }
    }

    func createForChainTypes(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem,
        chainTypes: Data
    ) throws -> RuntimeTypeRegistryInfo {
        let runtimeMetadataContainer = try createRuntimeContainer(from: runtimeMetadataItem)

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId)

        switch runtimeMetadataContainer.runtimeMetadata {
        case let .v13(metadata):
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                chainTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata)
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        case let .v14(metadata):
            let catalog = try TypeRegistryCatalog.createFromSiDefinition(
                versioningData: chainTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata),
                customTypeMapper: CustomSiMappers.all,
                customNameMapper: ScaleInfoCamelCaseMapper()
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        case let .v15(metadata):
            let catalog = try TypeRegistryCatalog.createFromSiDefinition(
                versioningData: chainTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata),
                customTypeMapper: CustomSiMappers.all,
                customNameMapper: ScaleInfoCamelCaseMapper()
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        }
    }

    func createForCommonTypes(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem,
        commonTypes: Data
    ) throws -> RuntimeTypeRegistryInfo {
        let runtimeMetadataContainer = try createRuntimeContainer(from: runtimeMetadataItem)
        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId)

        switch runtimeMetadataContainer.runtimeMetadata {
        case let .v13(metadata):
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                commonTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata)
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        case let .v14(metadata):
            let catalog = try TypeRegistryCatalog.createFromSiDefinition(
                versioningData: commonTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata),
                customTypeMapper: CustomSiMappers.all,
                customNameMapper: ScaleInfoCamelCaseMapper()
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        case let .v15(metadata):
            let catalog = try TypeRegistryCatalog.createFromSiDefinition(
                versioningData: commonTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata),
                customTypeMapper: CustomSiMappers.all,
                customNameMapper: ScaleInfoCamelCaseMapper()
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        }
    }

    func createForCommonAndChainTypes(
        chain: RuntimeProviderChain,
        runtimeMetadataItem: RuntimeMetadataItem,
        commonTypes: Data,
        chainTypes: Data
    ) throws -> RuntimeTypeRegistryInfo {
        let runtimeMetadataContainer = try createRuntimeContainer(from: runtimeMetadataItem)
        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId)

        switch runtimeMetadataContainer.runtimeMetadata {
        case let .v13(metadata):
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                commonTypes,
                versioningData: chainTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata)
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        case let .v14(metadata):
            let catalog = try TypeRegistryCatalog.createFromSiDefinition(
                versioningData: chainTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata),
                customTypeMapper: CustomSiMappers.all,
                customNameMapper: ScaleInfoCamelCaseMapper()
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        case let .v15(metadata):
            let catalog = try TypeRegistryCatalog.createFromSiDefinition(
                versioningData: chainTypes,
                runtimeMetadata: metadata,
                customExtensions: signedExtensionFactory.createCoders(for: metadata),
                customTypeMapper: CustomSiMappers.all,
                customNameMapper: ScaleInfoCamelCaseMapper()
            )

            return RuntimeTypeRegistryInfo(runtimeMetadata: metadata, typeRegistryCatalog: catalog)
        }
    }
}
