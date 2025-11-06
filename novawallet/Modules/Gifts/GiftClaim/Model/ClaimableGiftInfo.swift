import Foundation
import BigInt

struct ClaimableGiftInfo: Codable {
    let seed: Data
    let chainId: ChainModel.Id
    let assetSymbol: AssetModel.Symbol
}
