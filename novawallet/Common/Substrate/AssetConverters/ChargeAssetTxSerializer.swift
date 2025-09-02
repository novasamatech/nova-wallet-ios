import Foundation
import SubstrateSdk

enum ChargeAssetTxSerializerError: Error {
    case feeAssetIdTypeNotFound
}

enum ChargeAssetTxSerializer {
    private static func extractFeeAssetIdType(from codingFactory: RuntimeCoderFactoryProtocol) -> String? {
        guard
            let extensionType = codingFactory.metadata.getSignedExtensionType(
                for: Extrinsic.TransactionExtensionId.assetTxPayment
            ),
            let extensionTypeNode = codingFactory.getTypeNode(for: extensionType) as? StructNode,
            let assetIdType = extensionTypeNode.typeMapping.first(
                where: { $0.name == "assetId" }
            )?.node.typeName else {
            return nil
        }

        return assetIdType
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
            throw ChargeAssetTxSerializerError.feeAssetIdTypeNotFound
        }

        let data = try Data(hexString: assetId)

        let decoder = try codingFactory.createDecoder(from: data)

        return try decoder.read(type: assetIdType)
    }
}
