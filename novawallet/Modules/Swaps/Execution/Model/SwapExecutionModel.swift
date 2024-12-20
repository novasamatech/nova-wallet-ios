import Foundation

struct SwapExecutionModel {
    let chainAssetIn: ChainAsset
    let chainAssetOut: ChainAsset
    let feeAsset: ChainAsset
    let quote: AssetExchangeQuote
    let fee: AssetExchangeFee
}
