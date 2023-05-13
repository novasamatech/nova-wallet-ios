import Foundation
import SubstrateSdk

protocol RuntimeCoderFactoryProtocol {
    var specVersion: UInt32 { get }
    var txVersion: UInt32 { get }
    var metadata: RuntimeMetadataProtocol { get }

    func createEncoder() -> DynamicScaleEncoding
    func createDecoder(from data: Data) throws -> DynamicScaleDecoding
    func createRuntimeJsonContext() -> RuntimeJsonContext

    func hasType(for name: String) -> Bool
    func getTypeNode(for name: String) -> Node?
    func getCall(for codingPath: CallCodingPath) -> CallMetadata?
}

extension RuntimeCoderFactoryProtocol {
    func hasCall(for codingPath: CallCodingPath) -> Bool {
        getCall(for: codingPath) != nil
    }
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

    func hasType(for name: String) -> Bool {
        catalog.node(for: name, version: UInt64(specVersion)) != nil
    }

    func getTypeNode(for name: String) -> Node? {
        let node = catalog.node(for: name, version: UInt64(specVersion))

        if let aliasNode = node as? AliasNode {
            return getTypeNode(for: aliasNode.underlyingTypeName)
        } else if let proxyNode = node as? ProxyNode {
            return getTypeNode(for: proxyNode.typeName)
        } else {
            return node
        }
    }

    func getCall(for codingPath: CallCodingPath) -> CallMetadata? {
        metadata.getCall(from: codingPath.moduleName, with: codingPath.callName)
    }
}
