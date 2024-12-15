import Foundation

protocol AssetExchangePriceStoring {
    func getCurrencyId() -> Int?
    func fetchPrice(for chainAssetId: ChainAssetId) -> PriceData?
}
