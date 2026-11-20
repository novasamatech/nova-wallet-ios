import Foundation
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class RuntimeCodingServiceStub {
    let factory: RuntimeCoderFactoryProtocol

    init(factory: RuntimeCoderFactoryProtocol) {
        self.factory = factory
    }
}

extension RuntimeCodingServiceStub: RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { self.factory }
    }
}

extension RuntimeCodingServiceStub {
    static func createWestendCodingFactory(
        specVersion: UInt32 = 48,
        txVersion: UInt32 = 4
    ) throws -> RuntimeCoderFactoryProtocol {
        let runtimeMetadataContainer = try RuntimeHelper.createRuntimeMetadata("westend-metadata")
        let typeCatalog = try RuntimeHelper.createTypeRegistryCatalog(
            from: "runtime-default",
            networkName: "runtime-westend",
            runtimeMetadataContainer: runtimeMetadataContainer
        )

        return RuntimeCoderFactory(
            catalog: typeCatalog,
            specVersion: specVersion,
            txVersion: txVersion,
            metadata: runtimeMetadataContainer.metadata
        )
    }

    static func createWestendService(
        specVersion: UInt32 = 48,
        txVersion: UInt32 = 4
    ) throws -> RuntimeCodingServiceProtocol {
        let factory = try createWestendCodingFactory(specVersion: specVersion, txVersion: txVersion)
        return RuntimeCodingServiceStub(factory: factory)
    }

    static func createBittensorCodingFactory(
        specVersion: UInt32 = 470,
        txVersion: UInt32 = 1
    ) throws -> RuntimeCoderFactoryProtocol {
        let runtimeMetadataContainer = try RuntimeHelper.createRuntimeMetadata("bittensor-v15-metadata")

        guard case let .v15(metadata) = runtimeMetadataContainer.runtimeMetadata else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let augmentationResult = RuntimeAugmentationFactory().createSubstrateAugmentation(for: metadata)

        let typeCatalog = try TypeRegistryCatalog.createFromSiDefinition(
            runtimeMetadata: metadata,
            additionalNodes: augmentationResult.additionalNodes.nodes,
            customExtensions: DefaultSignedExtensionCoders.createDefaultCoders(for: metadata),
            customTypeMapper: CustomSiMappers.all,
            customNameMapper: ScaleInfoCamelCaseMapper()
        )

        return RuntimeCoderFactory(
            catalog: typeCatalog,
            specVersion: specVersion,
            txVersion: txVersion,
            metadata: metadata
        )
    }
}

extension RuntimeCodingServiceStub {
    /// Polkadot Asset Hub runtime (spec 2005000, metadata v15) with the app's default typing,
    /// the same path `RuntimeTypeRegistryFactory` takes for chains without custom types.
    static func createPolkadotAssetHubCodingFactory(
        specVersion: UInt32 = 2_005_000,
        txVersion: UInt32 = 15
    ) throws -> RuntimeCoderFactoryProtocol {
        let container = try RuntimeHelper.createRuntimeMetadata("polkadot-asset-hub-metadata")

        let metadata: PostV14RuntimeMetadataProtocol

        switch container.runtimeMetadata {
        case let .v14(v14):
            metadata = v14
        case let .v15(v15):
            metadata = v15
        case .v13:
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let augmentation = RuntimeAugmentationFactory().createSubstrateAugmentation(for: metadata)
        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(
            for: KnowChainId.polkadotAssetHub
        )

        let catalog = try TypeRegistryCatalog.createFromSiDefinition(
            runtimeMetadata: metadata,
            additionalNodes: augmentation.additionalNodes.nodes,
            customExtensions: signedExtensionFactory.createCoders(for: metadata),
            customTypeMapper: CustomSiMappers.all,
            customNameMapper: ScaleInfoCamelCaseMapper()
        )

        return RuntimeCoderFactory(
            catalog: catalog,
            specVersion: specVersion,
            txVersion: txVersion,
            metadata: metadata
        )
    }

    static func createPolkadotAssetHubService() throws -> RuntimeCodingServiceProtocol {
        RuntimeCodingServiceStub(factory: try createPolkadotAssetHubCodingFactory())
    }
}

extension RuntimeCodingServiceStub {
    /// Avail mainnet runtime (spec 56, tx 1, metadata v14) typed the way `RuntimeTypeRegistryFactory` does for
    /// a chain with its own types file (`runtime-avail.json` mirrors nova-utils `chains/v2/types/avail.json`);
    /// the only fixture that carries the `CheckAppId` signed extension.
    static func createAvailCodingFactory(
        specVersion: UInt32 = 56,
        txVersion: UInt32 = 1
    ) throws -> RuntimeCoderFactoryProtocol {
        let container = try RuntimeHelper.createRuntimeMetadata("avail-metadata")

        guard
            case let .v14(metadata) = container.runtimeMetadata,
            let typesUrl = RuntimeHelper.testBundle.url(forResource: "runtime-avail", withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let signedExtensionFactory = ExtrinsicSignedExtensionFacade().createFactory(for: KnowChainId.avail)

        let catalog = try TypeRegistryCatalog.createFromSiDefinition(
            versioningData: try Data(contentsOf: typesUrl),
            runtimeMetadata: metadata,
            customExtensions: signedExtensionFactory.createCoders(for: metadata),
            customTypeMapper: CustomSiMappers.all,
            customNameMapper: ScaleInfoCamelCaseMapper()
        )

        return RuntimeCoderFactory(
            catalog: catalog,
            specVersion: specVersion,
            txVersion: txVersion,
            metadata: metadata
        )
    }
}
