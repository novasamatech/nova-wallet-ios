import Foundation
import SubstrateSdk
import SoraFoundation
import BigInt

struct WalletListAssetAccountPrice {
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt
    let price: PriceData
}

struct WalletListAssetAccountInfo {
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt?
    let priceData: PriceData?
}

protocol WalletListViewModelFactoryProtocol {
    func createHeaderViewModel(
        from title: String,
        accountId: AccountId,
        prices: LoadableViewModelState<[WalletListAssetAccountPrice]>?,
        locale: Locale
    ) -> WalletListHeaderViewModel

    func createGroupViewModel(
        for chain: ChainModel,
        assets: [WalletListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> WalletListGroupViewModel

    func createAssetViewModel(
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> WalletListAssetViewModel
}

final class WalletListViewModelFactory {
    let priceFormatter: LocalizableResource<TokenFormatter>
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>

    private lazy var cssColorFactory = CSSGradientFactory()

    init(
        priceFormatter: LocalizableResource<TokenFormatter>,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.priceFormatter = priceFormatter
        self.assetFormatterFactory = assetFormatterFactory
        self.percentFormatter = percentFormatter
    }

    private lazy var iconGenerator = NovaIconGenerator()

    private func formatTotalPrice(from prices: [WalletListAssetAccountPrice], locale: Locale) -> String {
        let totalPrice = prices.reduce(Decimal(0)) { result, item in
            let balance = Decimal.fromSubstrateAmount(
                item.balance,
                precision: item.assetInfo.assetPrecision
            ) ?? 0.0

            let price = Decimal(string: item.price.price) ?? 0.0

            return result + balance * price
        }

        return priceFormatter.value(for: locale).stringFromDecimal(totalPrice) ?? ""
    }

    private func createTotalPrice(
        from prices: LoadableViewModelState<[WalletListAssetAccountPrice]>,
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
        prices: LoadableViewModelState<[WalletListAssetAccountPrice]>?,
        locale: Locale
    ) -> WalletListHeaderViewModel {
        let icon = try? iconGenerator.generateFromAccountId(accountId)

        // TODO: Add locks handling
        if let prices = prices {
            let totalPrice = createTotalPrice(from: prices, locale: locale)
            return WalletListHeaderViewModel(
                title: title,
                amount: totalPrice,
                locked: .loaded(value: "0"),
                icon: icon
            )
        } else {
            return WalletListHeaderViewModel(
                title: title,
                amount: .loading,
                locked: .loaded(value: "0"),
                icon: icon
            )
        }
    }

    func createGroupViewModel(
        for chain: ChainModel,
        assets: [WalletListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> WalletListGroupViewModel {
        let assetViewModels = assets.map { asset in
            createAssetViewModel(
                assetAccountInfo: asset,
                connected: connected,
                locale: locale
            )
        }

        let networkName = chain.name.uppercased()

        let iconViewModel = RemoteImageViewModel(url: chain.icon)

        let priceString = priceFormatter.value(for: locale).stringFromDecimal(value) ?? ""

        let color: GradientModel

        if let colorModel = cssColorFactory.createFromString(chain.color) {
            color = colorModel
        } else {
            color = GradientModel.defaultGradient
        }

        return WalletListGroupViewModel(
            networkName: networkName,
            amount: .loaded(value: priceString),
            icon: iconViewModel,
            color: color,
            assets: assetViewModels
        )
    }

    func createAssetViewModel(
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> WalletListAssetViewModel {
        let priceState: LoadableViewModelState<WalletPriceViewModel>

        if
            let priceString = assetAccountInfo.priceData?.price,
            let price = Decimal(string: priceString) {
            let priceChangeValue = (assetAccountInfo.priceData?.usdDayChange ?? 0.0) / 100.0
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

        let assetInfo = assetAccountInfo.assetInfo

        if let balance = assetAccountInfo.balance {
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

            if
                let priceData = assetAccountInfo.priceData,
                let decimalPrice = Decimal(string: priceData.price) {
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

        return WalletListAssetViewModel(
            tokenName: assetInfo.symbol.uppercased(),
            icon: iconViewModel,
            price: priceState,
            balanceAmount: balanceState,
            balanceValue: balanceValueState
        )
    }
}
