import Foundation
import BigInt
import SubstrateSdk

class AssetConversionTxPayment: Codable, ExtrinsicExtension {
    public static let name: String = "ChargeAssetTxPayment"

    @StringCodable public var tip: BigUInt
    let assetId: AssetConversionPallet.AssetId?

    init(tip: BigUInt = 0, assetId: AssetConversionPallet.AssetId? = nil) {
        self.tip = tip
        self.assetId = assetId
    }
}
