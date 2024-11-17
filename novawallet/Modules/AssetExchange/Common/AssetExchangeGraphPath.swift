import Foundation

struct AssetExchangeQuotePathItem {
    let edge: AnyAssetExchangeEdge
    let assetIn: ChainAsset
    let assetOut: ChainAsset
    let priceIn: PriceData?
    let priceOut: PriceData?
}

typealias AssetExchangeQuotePath = [AssetExchangeQuotePathItem]

typealias AssetExchangeGraphPath = [AnyAssetExchangeEdge]
