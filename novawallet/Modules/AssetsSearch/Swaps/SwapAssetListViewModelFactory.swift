import Foundation

final class SwapAssetListViewModelFactory: AssetListAssetViewModelFactory {
    override func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        guard amount > 0 else {
            return ""
        }

        let formattedPrice = super.formatPrice(
            amount: amount,
            priceData: priceData,
            locale: locale
        )
        return wrap(price: formattedPrice)
    }

    override func createBalanceState(
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> (LoadableViewModelState<String>, LoadableViewModelState<String>) {
        let (balanceState, priceState) = super.createBalanceState(
            assetAccountInfo: assetAccountInfo,
            connected: connected,
            locale: locale
        )
        guard let balance = assetAccountInfo.balance, balance > 0 else {
            return (balanceState, priceState)
        }

        switch priceState {
        case .loading:
            return (balanceState, priceState)
        case let .cached(value):
            return (balanceState, .cached(value: wrap(price: value)))
        case let .loaded(value):
            return (balanceState, .loaded(value: wrap(price: value)))
        }
    }

    private func wrap(price: String) -> String {
        guard !price.isEmpty else {
            return price
        }
        return "~\(price)"
    }
}
