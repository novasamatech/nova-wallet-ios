import Foundation

struct SwapExecutionModel {
    let chainAssetIn: ChainAsset
    let chainAssetOut: ChainAsset
    let feeAsset: ChainAsset
    let quote: AssetExchangeQuote
    let fee: AssetExchangeFee
    let prices: [ChainAssetId: PriceData]

    var payAssetPrice: PriceData? {
        prices[chainAssetIn.chainAssetId]
    }

    var receiveAssetPrice: PriceData? {
        prices[chainAssetOut.chainAssetId]
    }

    var feeAssetPrice: PriceData? {
        prices[feeAsset.chainAssetId]
    }
}
