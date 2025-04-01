import Foundation
import BigInt
import SubstrateSdk

class AssetConversionTxPayment<AssetId: Codable>: Codable, OnlyExtrinsicSignedExtending {
    public var signedExtensionId: String { "ChargeAssetTxPayment" }

    @StringCodable public var tip: BigUInt
    let assetId: AssetId?

    init(tip: BigUInt = 0, assetId: AssetId? = nil) {
        self.tip = tip
        self.assetId = assetId
    }
}
