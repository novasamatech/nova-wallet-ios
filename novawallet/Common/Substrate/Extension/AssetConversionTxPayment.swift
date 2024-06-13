import Foundation
import BigInt
import SubstrateSdk

class AssetConversionTxPayment: Codable, OnlyExtrinsicSignedExtending {
    public var signedExtensionId: String { "ChargeAssetTxPayment" }

    @StringCodable public var tip: BigUInt
    let assetId: AssetConversionPallet.AssetId?

    init(tip: BigUInt = 0, assetId: AssetConversionPallet.AssetId? = nil) {
        self.tip = tip
        self.assetId = assetId
    }
}
