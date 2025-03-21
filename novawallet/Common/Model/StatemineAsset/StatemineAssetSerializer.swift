import Foundation
import SubstrateSdk
import BigInt

enum StatemineAssetSerializerError: Error {
    case assetIdTypeNotFound(palletName: String?)
    case feeAssetIdTypeNotFound
}

enum StatemineAssetSerializer {
    private static func extractAssetIdType(
        from codingFactory: RuntimeCoderFactoryProtocol,
        palletName: String?
    ) -> String? {
        let callPath = PalletAssets.assetsTransfer(for: palletName)

        guard let call = codingFactory.getCall(for: callPath), !call.arguments.isEmpty else {
            return nil
        }

        return call.arguments[0].type
    }

    private static func extractFeeAssetIdType(from codingFactory: RuntimeCoderFactoryProtocol) -> String? {
        guard
            let extensionType = codingFactory.metadata.getSignedExtensionType(
                for: Extrinsic.SignedExtensionId.assetTxPayment
            ),
            let extensionTypeNode = codingFactory.getTypeNode(for: extensionType) as? StructNode,
            let assetIdType = extensionTypeNode.typeMapping.first(
                where: { $0.name == "assetId" }
            )?.node.typeName else {
            return nil
        }

        return assetIdType
    }

    static func decode(
        assetId: String,
        palletName: String?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> JSON {
        // assetId is either integer or complicated data structure
        guard assetId.isHex() else {
            return JSON.stringValue(assetId)
        }

        guard let assetIdType = extractAssetIdType(from: codingFactory, palletName: palletName) else {
            throw StatemineAssetSerializerError.assetIdTypeNotFound(palletName: palletName)
        }

        let data = try Data(hexString: assetId)

        let decoder = try codingFactory.createDecoder(from: data)

        return try decoder.read(type: assetIdType)
    }

    static func decodeFeeAssetId(
        _ assetId: String,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> JSON {
        // assetId is either integer or complicated data structure
        guard assetId.isHex() else {
            return JSON.stringValue(assetId)
        }

        guard let assetIdType = extractFeeAssetIdType(from: codingFactory) else {
            throw StatemineAssetSerializerError.feeAssetIdTypeNotFound
        }

        let data = try Data(hexString: assetId)

        let decoder = try codingFactory.createDecoder(from: data)

        return try decoder.read(type: assetIdType)
    }

    static func encode(
        assetId: JSON,
        palletName: String?,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> String {
        // assetId is either integer or complicated data structure
        if case let .stringValue(assetIdString) = assetId, BigUInt(assetIdString) != nil {
            return assetIdString
        }

        guard let assetIdType = extractAssetIdType(from: codingFactory, palletName: palletName) else {
            throw StatemineAssetSerializerError.assetIdTypeNotFound(palletName: palletName)
        }

        let encoder = codingFactory.createEncoder()

        try encoder.append(json: assetId, type: assetIdType)

        let data = try encoder.encode()

        return data.toHex(includePrefix: true)
    }

    static func subscriptionKeyEncoder(for assetId: String) -> ((String) throws -> Data)? {
        if assetId.isHex() {
            return { try Data(hexString: $0) }
        } else {
            return nil
        }
    }
}
