import Foundation

protocol AssetExchangePriceStoring {
    func fetchPrice(for chainAssetId: ChainAssetId) -> PriceData?
}
