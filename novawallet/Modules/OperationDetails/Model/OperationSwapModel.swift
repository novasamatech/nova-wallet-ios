import Foundation
import BigInt

struct OperationSwapModel {
    let txHash: String
    let chain: ChainModel
    let assetIn: AssetModel
    let amountIn: BigUInt
    let priceIn: PriceData?
    let assetOut: AssetModel
    let amountOut: BigUInt
    let priceOut: PriceData?
    let fee: BigUInt
    let feePrice: PriceData?
    let feeAsset: AssetModel
    let wallet: WalletDisplayAddress
    let isOutgoing: Bool
}
