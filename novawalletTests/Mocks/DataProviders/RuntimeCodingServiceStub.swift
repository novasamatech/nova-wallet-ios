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
