import Foundation
import FearlessUtils

enum RuntimeHelperError: Error {
    case invalidCatalogBaseName
    case invalidCatalogNetworkName
    case invalidCatalogMetadataName
}

extension RuntimeMetadataContainer {
    var metadata: RuntimeMetadataProtocol {
        switch self.runtimeMetadata {
        case .v13(let metadata):
            return metadata
        case .v14(let metadata):
            return metadata
        }
    }
}

final class RuntimeHelper {
    static func createRuntimeMetadata(_ name: String) throws -> RuntimeMetadataContainer {
        guard let metadataUrl = Bundle(for: self).url(forResource: name,
                                                      withExtension: "") else {
            throw RuntimeHelperError.invalidCatalogMetadataName
        }

        let hex = try String(contentsOf: metadataUrl)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let expectedData = try Data(hexString: hex)

        let decoder = try ScaleDecoder(data: expectedData)
        let container = try RuntimeMetadataContainer(scaleDecoder: decoder)

        return container
    }

    static func createTypeRegistry(from name: String, runtimeMetadataName: String) throws
    -> TypeRegistry {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        let runtimeMetadataContainer = try Self.createRuntimeMetadata(runtimeMetadataName)

        let data = try Data(contentsOf: url)
        let basisNodes = BasisNodes.allNodes(for: runtimeMetadataContainer.metadata)
        let registry = try TypeRegistry
            .createFromTypesDefinition(data: data,
                                       additionalNodes: basisNodes)

        return registry
    }

    static func createTypeRegistryCatalog(from baseName: String,
                                          networkName: String,
                                          runtimeMetadataName: String)
    throws -> TypeRegistryCatalog {
        let runtimeMetadataContainer = try Self.createRuntimeMetadata(runtimeMetadataName)

        return try createTypeRegistryCatalog(from: baseName,
                                             networkName: networkName,
                                             runtimeMetadataContainer: runtimeMetadataContainer
        )
    }

    static func createTypeRegistryCatalog(from baseName: String,
                                          networkName: String,
                                          runtimeMetadataContainer: RuntimeMetadataContainer)
    throws -> TypeRegistryCatalog {
        guard let baseUrl = Bundle.main.url(forResource: baseName, withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogBaseName
        }

        guard let networkUrl = Bundle.main.url(forResource: networkName,
                                               withExtension: "json") else {
            throw RuntimeHelperError.invalidCatalogNetworkName
        }

        let baseData = try Data(contentsOf: baseUrl)
        let networkData = try Data(contentsOf: networkUrl)

        switch runtimeMetadataContainer.runtimeMetadata {
        case .v13(let metadata):
            return try TypeRegistryCatalog.createFromTypeDefinition(
                baseData,
                versioningData: networkData,
                runtimeMetadata: metadata
            )
        case .v14(let metadata):
            return try TypeRegistryCatalog.createFromSiDefinition(
                versioningData: networkData,
                runtimeMetadata: metadata
            )
        }


    }

    static let dummyRuntimeMetadata: RuntimeMetadata = {
        RuntimeMetadata(modules: [
                            ModuleMetadata(name: "A",
                                           storage: StorageMetadata(prefix: "_A", entries: []),
                                           calls: [
                                            CallMetadata(name: "B",
                                                             arguments: [
                                                                CallArgumentMetadata(name: "arg1", type: "bool"),
                                                                CallArgumentMetadata(name: "arg2", type: "u8")
                                                             ], documentation: [])
                                           ],
                                           events: [
                                            EventMetadata(name: "A",
                                                          arguments: ["bool", "u8"],
                                                          documentation: [])
                                           ],
                                           constants: [],
                                           errors: [],
                                           index: 1)
                        ],
                        extrinsic: ExtrinsicMetadata(version: 1,
                                                     signedExtensions: []))
    }()
}
