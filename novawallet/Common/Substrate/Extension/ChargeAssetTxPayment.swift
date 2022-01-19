import Foundation
import SubstrateSdk
import BigInt

enum ChargeAssetTxPaymentConstants {
    static let tip = "tip"
    static let assetId = "assetId"
    static let name = "ChargeAssetTxPayment"
}

final class ChargeAssetTxPayment {
    let tip: BigUInt
    let assetId: UInt32?

    init(tip: BigUInt = 0, assetId: UInt32? = nil) {
        self.tip = tip
        self.assetId = assetId
    }
}

extension ChargeAssetTxPayment: ExtrinsicExtension {
    var name: String { ChargeAssetTxPaymentConstants.name }

    func setAdditionalExtra(to extraStore: inout ExtrinsicExtra) {
        extraStore[ChargeAssetTxPaymentConstants.tip] = .stringValue(String(tip))

        if let assetId = assetId {
            extraStore[ChargeAssetTxPaymentConstants.assetId] = .stringValue(String(assetId))
        } else {
            extraStore[ChargeAssetTxPaymentConstants.assetId] = .null
        }
    }
}

final class ChargeAssetTxPaymentCoder: ExtrinsicExtensionCoder {
    var name: String { ChargeAssetTxPaymentConstants.name }

    func decodeAdditionalExtra(to extraStore: inout ExtrinsicExtra, decoder: DynamicScaleDecoding) throws {
        extraStore[ChargeAssetTxPaymentConstants.tip] = try decoder.read(type: KnownType.balance.name)
        extraStore[ChargeAssetTxPaymentConstants.assetId] = try decoder.readOption(type: PrimitiveType.u32.name)
    }

    func encodeAdditionalExtra(from extra: ExtrinsicExtra, encoder: DynamicScaleEncoding) throws {
        if let tipJson = extra[ChargeAssetTxPaymentConstants.tip] {
            try encoder.appendCompact(json: tipJson, type: KnownType.balance.name)
        } else {
            throw ExtrinsicExtraNodeError.invalidParams
        }

        if let assetId = extra[ChargeAssetTxPaymentConstants.assetId] {
            try encoder.appendOption(json: assetId, type: PrimitiveType.u32.name)
        } else {
            throw ExtrinsicExtraNodeError.invalidParams
        }
    }
}
