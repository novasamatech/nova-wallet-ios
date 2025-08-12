import Foundation
import SubstrateSdk

protocol RuntimeCoderFactoryProtocol: DynamicScaleEncodingFactoryProtocol {
    var specVersion: UInt32 { get }
    var txVersion: UInt32 { get }
    var metadata: RuntimeMetadataProtocol { get }

    func createEncoder() -> DynamicScaleEncoding
    func createDecoder(from data: Data) throws -> DynamicScaleDecoding
    func createRuntimeJsonContext() -> RuntimeJsonContext

    func hasType(for name: String) -> Bool
    func getTypeNode(for name: String) -> Node?
    func getCall(for codingPath: CallCodingPath) -> CallMetadata?
    func getConstant(for codingPath: ConstantCodingPath) -> ModuleConstantMetadata?
}

extension RuntimeCoderFactoryProtocol {
    func hasCall(for codingPath: CallCodingPath) -> Bool {
        getCall(for: codingPath) != nil
    }

    func hasConstant(for codingPath: ConstantCodingPath) -> Bool {
        getConstant(for: codingPath) != nil
    }

    func hasStorage(for storagePath: StorageCodingPath) -> Bool {
        metadata.getStorageMetadata(for: storagePath) != nil
    }

    func atLeastV15Runtime() -> Bool {
        if metadata is RuntimeMetadata || metadata is RuntimeMetadataV14 {
            return false
        } else {
            return true
        }
    }

    func supportsMetadataHash() -> Bool {
        let hasSignedExtension = metadata.getSignedExtensions().contains(
            Extrinsic.TransactionExtensionId.checkMetadataHash
        )

        return atLeastV15Runtime() && hasSignedExtension
    }
}

final class RuntimeCoderFactory: RuntimeCoderFactoryProtocol {
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
        let isMultiaddress = catalog.nodeMatches(
            closure: { node in
                node is EnumNode || node is SiVariantNode || node is GenericMultiAddressNode
            },
            typeName: KnownType.address.name,
            version: UInt64(specVersion)
        )

        return RuntimeJsonContext(prefersRawAddress: !isMultiaddress)
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

    func getConstant(for codingPath: ConstantCodingPath) -> ModuleConstantMetadata? {
        metadata.getConstant(in: codingPath.moduleName, constantName: codingPath.constantName)
    }
}
