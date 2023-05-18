protocol PriceAssetInfoFactoryProtocol {
    func createAssetBalanceDisplayInfo(from priceId: Int?) -> AssetBalanceDisplayInfo
}

final class PriceAssetInfoFactory: PriceAssetInfoFactoryProtocol {
    private let currencyManager: CurrencyManagerProtocol

    init(currencyManager: CurrencyManagerProtocol) {
        self.currencyManager = currencyManager
    }

    func createAssetBalanceDisplayInfo(from priceId: Int?) -> AssetBalanceDisplayInfo {
        let mappedCurrencyId = priceId ?? currencyManager.selectedCurrency.id
        guard let currency = currencyManager.availableCurrencies.first(where: { $0.id == mappedCurrencyId }) else {
            assertionFailure("Currency with id: \(mappedCurrencyId) not found")
            return .usd()
        }
        return .from(currency: currency)
    }
}
