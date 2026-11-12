import Foundation

struct SwapAssetPairId: Codable, Equatable {
    let pay: ChainAssetId
    let receive: ChainAssetId

    enum CodingKeys: String, CodingKey {
        case pay = "assetIn"
        case receive = "assetOut"
    }
}
