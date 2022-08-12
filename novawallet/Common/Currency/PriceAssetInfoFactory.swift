protocol PriceAssetInfoFactoryProtocol {
    func createAssetBalanceDisplayInfo(from currencyId: Int) -> AssetBalanceDisplayInfo
}

final class PriceAssetInfoFactory: PriceAssetInfoFactoryProtocol {
    private let currencyManager: CurrencyManagerProtocol

    init(currencyManager: CurrencyManagerProtocol) {
        self.currencyManager = currencyManager
    }

    func createAssetBalanceDisplayInfo(from currencyId: Int) -> AssetBalanceDisplayInfo {
        guard let currency = currencyManager.availableCurrencies.first(where: { $0.id == currencyId }) else {
            assertionFailure("Currency with id: \(currencyId) not found")
            return .usd()
        }
        return .from(currency: currency)
    }
}
