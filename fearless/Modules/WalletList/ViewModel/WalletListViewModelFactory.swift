import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

struct WalletListChainAccountPrice {
    let assetInfo: AssetBalanceDisplayInfo
    let accountInfo: AccountInfo
    let price: PriceData
}

protocol WalletListViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        accountId: AccountId,
        prices: LoadableViewModelState<[WalletListChainAccountPrice]>?,
        locale: Locale
    ) -> WalletListHeaderViewModel

    func createAssetViewModel(
        for chain: ChainModel,
        assetInfo: AssetBalanceDisplayInfo,
        balance: BigUInt?,
        priceData: PriceData?,
        connected: Bool,
        locale: Locale
    ) -> WalletListViewModel
}

final class WalletListViewModelFactory {
    let priceFormatter: LocalizableResource<TokenFormatter>
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>

    init(
        priceFormatter: LocalizableResource<TokenFormatter>,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.priceFormatter = priceFormatter
        self.assetFormatterFactory = assetFormatterFactory
        self.percentFormatter = percentFormatter
    }

    private lazy var iconGenerator = PolkadotIconGenerator()

    private func formatTotalPrice(from prices: [WalletListChainAccountPrice], locale: Locale) -> String {
        let totalPrice = prices.reduce(Decimal(0)) { result, item in
            let balance = Decimal.fromSubstrateAmount(
                item.accountInfo.data.total,
                precision: item.assetInfo.assetPrecision
            ) ?? 0.0

            let price = Decimal(string: item.price.price) ?? 0.0

            return result + balance * price
        }

        return priceFormatter.value(for: locale).stringFromDecimal(totalPrice) ?? ""
    }

    private func createTotalPrice(
        from prices: LoadableViewModelState<[WalletListChainAccountPrice]>,
        locale: Locale
    ) -> LoadableViewModelState<String> {
        switch prices {
        case .loading:
            return .loading
        case let .cached(value):
            let formattedPrice = formatTotalPrice(from: value, locale: locale)
            return .cached(value: formattedPrice)
        case let .loaded(value):
            let formattedPrice = formatTotalPrice(from: value, locale: locale)
            return .loaded(value: formattedPrice)
        }
    }
}

extension WalletListViewModelFactory: WalletListViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        accountId: AccountId,
        prices: LoadableViewModelState<[WalletListChainAccountPrice]>?,
        locale: Locale
    ) -> WalletListHeaderViewModel {
        let icon = try? iconGenerator.generateFromAccountId(accountId)

        if let prices = prices {
            let totalPrice = createTotalPrice(from: prices, locale: locale)
            return WalletListHeaderViewModel(title: title, amount: totalPrice, icon: icon)
        } else {
            return WalletListHeaderViewModel(title: title, amount: .loading, icon: icon)
        }
    }

    func createAssetViewModel(
        for chain: ChainModel,
        assetInfo: AssetBalanceDisplayInfo,
        balance: BigUInt?,
        priceData: PriceData?,
        connected: Bool,
        locale: Locale
    ) -> WalletListViewModel {
        let priceState: LoadableViewModelState<WalletPriceViewModel>

        if
            let priceString = priceData?.price,
            let price = Decimal(string: priceString) {
            let priceChangeValue = (priceData?.usdDayChange ?? 0.0) / 100.0
            let priceChangeString = percentFormatter.value(for: locale)
                .stringFromDecimal(priceChangeValue) ?? ""
            let priceString = priceFormatter.value(for: locale)
                .stringFromDecimal(price) ?? ""

            let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
                ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
            priceState = .loaded(value: WalletPriceViewModel(amount: priceString, change: priceChange))
        } else {
            priceState = .loading
        }

        let balanceState: LoadableViewModelState<String>
        let balanceValueState: LoadableViewModelState<String>

        if let balance = balance {
            let decimalBalance = Decimal.fromSubstrateAmount(
                balance,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let balanceFormatter = assetFormatterFactory.createDisplayFormatter(for: assetInfo)

            let balanceAmountString = balanceFormatter.value(for: locale).stringFromDecimal(
                decimalBalance
            ) ?? ""

            balanceState = connected ? .loaded(value: balanceAmountString) :
                .cached(value: balanceAmountString)

            if let priceData = priceData, let decimalPrice = Decimal(string: priceData.price) {
                let balanceValue = priceFormatter.value(for: locale).stringFromDecimal(
                    decimalBalance * decimalPrice
                ) ?? ""
                balanceValueState = .loaded(value: balanceValue)
            } else {
                balanceValueState = .loading
            }

        } else {
            balanceState = .loading
            balanceValueState = .loading
        }

        let iconViewModel = assetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return WalletListViewModel(
            networkName: chain.name.uppercased(),
            tokenName: assetInfo.symbol.uppercased(),
            icon: iconViewModel,
            price: priceState,
            balanceAmount: balanceState,
            balanceValue: balanceValueState
        )
    }
}
