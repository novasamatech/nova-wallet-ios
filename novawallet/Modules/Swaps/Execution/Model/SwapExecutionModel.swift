import Foundation

struct SwapExecutionModel {
    let chainAssetIn: ChainAsset
    let chainAssetOut: ChainAsset
    let feeAsset: ChainAsset
    let quote: AssetExchangeQuote
    let fee: AssetExchangeFee
    let prices: [AssetModel.PriceId: PriceData]

    var payAssetPrice: PriceData? {
        chainAssetIn.asset.priceId.flatMap { prices[$0] }
    }

    var receiveAssetPrice: PriceData? {
        chainAssetOut.asset.priceId.flatMap { prices[$0] }
    }

    var feeAssetPrice: PriceData? {
        feeAsset.asset.priceId.flatMap { prices[$0] }
    }
}
