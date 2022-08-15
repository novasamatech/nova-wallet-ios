protocol PriceAssetInfoFactoryProtocol {
    func createAssetBalanceDisplayInfo(from currencyId: Int?) -> AssetBalanceDisplayInfo
}

final class PriceAssetInfoFactory: PriceAssetInfoFactoryProtocol {
    private let currencyManager: CurrencyManagerProtocol

    init(currencyManager: CurrencyManagerProtocol) {
        self.currencyManager = currencyManager
    }

    func createAssetBalanceDisplayInfo(from _: Int?) -> AssetBalanceDisplayInfo {
        let mappedCurrencyId = currencyManager.selectedCurrency.id
        guard let currency = currencyManager.availableCurrencies.first(where: { $0.id == mappedCurrencyId }) else {
            assertionFailure("Currency with id: \(mappedCurrencyId) not found")
            return .usd()
        }
        return .from(currency: currency)
    }
}
