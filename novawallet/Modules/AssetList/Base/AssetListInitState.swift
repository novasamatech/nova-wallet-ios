import Foundation
import BigInt

struct AssetListInitState {
    let priceResult: Result<[ChainAssetId: PriceData], Error>?
    let balanceResults: [ChainAssetId: Result<BigUInt, Error>]
    let allChains: [ChainModel.Id: ChainModel]
}
