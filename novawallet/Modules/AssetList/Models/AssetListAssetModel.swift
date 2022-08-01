import Foundation
import BigInt
import RobinHood

struct AssetListAssetModel: Identifiable {
    var identifier: String { String(assetModel.assetId) }

    let assetModel: AssetModel
    let balanceResult: Result<BigUInt, Error>?
    let assetValue: Decimal?
}
