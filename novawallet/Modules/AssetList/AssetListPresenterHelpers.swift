import Foundation

enum AssetListPresenterHelpers {
    static func createAssetAccountInfo(
        from asset: AssetListAssetModel,
        chain: ChainModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListAssetAccountInfo {
        let assetModel = asset.chainAssetModel.asset
        let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: assetModel.assetId)

        let assetInfo = assetModel.displayInfo

        let priceData: PriceData?

        if let prices = maybePrices {
            priceData = prices[chainAssetId] ?? PriceData.zero()
        } else {
            priceData = nil
        }

        return AssetListAssetAccountInfo(
            assetId: asset.chainAssetModel.asset.assetId,
            assetInfo: assetInfo,
            balance: asset.totalAmount,
            priceData: priceData
        )
    }
}
