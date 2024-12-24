import Foundation

protocol AssetExchageUsdtConverting {
    func convertToUsdt(the asset: ChainAsset, decimalAmount: Decimal) -> Decimal?
    func convertToAssetDecimalFromUsdt(amount: Decimal, asset: ChainAsset) -> Decimal?
}

extension AssetExchageUsdtConverting {
    func convertToUsdt(the asset: ChainAsset, amountInPlank: Balance) -> Decimal? {
        let decimalAmount = amountInPlank.decimal(assetInfo: asset.assetDisplayInfo)

        return convertToUsdt(the: asset, decimalAmount: decimalAmount)
    }

    func convertToAssetInPlankFromUsdt(amount: Decimal, asset: ChainAsset) -> Balance? {
        let decimalAmount = convertToAssetDecimalFromUsdt(amount: amount, asset: asset)

        return decimalAmount?.toSubstrateAmount(precision: asset.assetDisplayInfo.assetPrecision)
    }
}

final class AssetExchageUsdtConverter {
    let priceStore: AssetExchangePriceStoring
    let usdtTiedAsset: ChainAssetId

    init(priceStore: AssetExchangePriceStoring, usdtTiedAsset: ChainAssetId) {
        self.priceStore = priceStore
        self.usdtTiedAsset = usdtTiedAsset
    }
}

extension AssetExchageUsdtConverter: AssetExchageUsdtConverting {
    func convertToUsdt(the asset: ChainAsset, decimalAmount: Decimal) -> Decimal? {
        guard
            let usdtPriceRate = priceStore.fetchPrice(for: usdtTiedAsset)?.decimalRate,
            let assetPriceRate = priceStore.fetchPrice(for: asset.chainAssetId)?.decimalRate,
            usdtPriceRate > 0 else {
            return nil
        }

        return decimalAmount * assetPriceRate / usdtPriceRate
    }

    func convertToAssetDecimalFromUsdt(amount: Decimal, asset: ChainAsset) -> Decimal? {
        guard
            let usdtPriceRate = priceStore.fetchPrice(for: usdtTiedAsset)?.decimalRate,
            let assetPriceRate = priceStore.fetchPrice(for: asset.chainAssetId)?.decimalRate,
            assetPriceRate > 0 else {
            return nil
        }

        return amount * usdtPriceRate / assetPriceRate
    }
}
