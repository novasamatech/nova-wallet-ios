import Foundation
import SubstrateSdk

protocol RuntimeCoderFactoryProtocol {
    var specVersion: UInt32 { get }
    var txVersion: UInt32 { get }
    var metadata: RuntimeMetadataProtocol { get }

    func createEncoder() -> DynamicScaleEncoding
    func createDecoder(from data: Data) throws -> DynamicScaleDecoding
    func createRuntimeJsonContext() -> RuntimeJsonContext
}

final class RuntimeCoderFactory: RuntimeCoderFactoryProtocol {
    static let addressTypeName = "Address"

    let catalog: TypeRegistryCatalogProtocol
    let specVersion: UInt32
    let txVersion: UInt32
    let metadata: RuntimeMetadataProtocol

    init(
        catalog: TypeRegistryCatalogProtocol,
        specVersion: UInt32,
        txVersion: UInt32,
        metadata: RuntimeMetadataProtocol
    ) {
        self.catalog = catalog
        self.specVersion = specVersion
        self.txVersion = txVersion
        self.metadata = metadata
    }

    func createEncoder() -> DynamicScaleEncoding {
        DynamicScaleEncoder(registry: catalog, version: UInt64(specVersion))
    }

    func createDecoder(from data: Data) throws -> DynamicScaleDecoding {
        try DynamicScaleDecoder(data: data, registry: catalog, version: UInt64(specVersion))
    }

    func createRuntimeJsonContext() -> RuntimeJsonContext {
        if let addressTypeNode = catalog.node(
            for: Self.addressTypeName,
            version: UInt64(specVersion)
        ) as? ProxyNode {
            let addressTypeName = addressTypeNode.typeName.components(separatedBy: ".").last

            let preferresMultiAddress = addressTypeName?.lowercased() == "multiaddress"
            return RuntimeJsonContext(prefersRawAddress: !preferresMultiAddress)
        } else {
            return RuntimeJsonContext(prefersRawAddress: false)
        }
    }
}
