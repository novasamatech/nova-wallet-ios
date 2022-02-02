import Foundation
import BigInt
import RobinHood

struct WalletListAssetModel: Identifiable {
    var identifier: String { String(assetModel.assetId) }

    let assetModel: AssetModel
    let balanceResult: Result<BigUInt, Error>?
    let assetValue: Decimal?
}
