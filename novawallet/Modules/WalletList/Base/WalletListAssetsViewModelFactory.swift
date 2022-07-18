import Foundation
import SoraFoundation
import BigInt

struct WalletListAssetAccountInfo {
    let assetId: AssetModel.Id
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt?
    let priceData: PriceData?
}

protocol WalletListAssetViewModelFactoryProtocol {
    func createGroupViewModel(
        for chain: ChainModel,
        assets: [WalletListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> WalletListGroupViewModel

    func createAssetViewModel(
        chainId: ChainModel.Id,
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> WalletListAssetViewModel
}

class WalletListAssetViewModelFactory {
    let priceFormatter: LocalizableResource<TokenFormatter>
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>

    private(set) lazy var cssColorFactory = CSSGradientFactory()

    init(
        priceFormatter: LocalizableResource<TokenFormatter>,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>
    ) {
        self.priceFormatter = priceFormatter
        self.assetFormatterFactory = assetFormatterFactory
        self.percentFormatter = percentFormatter
    }

    func createBalanceState(
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> (LoadableViewModelState<String>, LoadableViewModelState<String>) {
        if let balance = assetAccountInfo.balance {
            let assetInfo = assetAccountInfo.assetInfo

            let decimalBalance = Decimal.fromSubstrateAmount(
                balance,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let balanceFormatter = assetFormatterFactory.createDisplayFormatter(for: assetInfo)

            let balanceAmountString = balanceFormatter.value(for: locale).stringFromDecimal(
                decimalBalance
            ) ?? ""

            let balanceState = connected ? LoadableViewModelState.loaded(value: balanceAmountString) :
                LoadableViewModelState.cached(value: balanceAmountString)

            if
                let priceData = assetAccountInfo.priceData,
                let decimalPrice = Decimal(string: priceData.price) {
                let balanceValue = priceFormatter.value(for: locale).stringFromDecimal(
                    decimalBalance * decimalPrice
                ) ?? ""
                return (balanceState, .loaded(value: balanceValue))
            } else {
                return (balanceState, .loading)
            }

        } else {
            return (.loading, .loading)
        }
    }

    func createPriceState(
        assetAccountInfo: WalletListAssetAccountInfo,
        locale: Locale
    ) -> LoadableViewModelState<WalletPriceViewModel> {
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
            return .loaded(value: WalletPriceViewModel(amount: priceString, change: priceChange))
        } else {
            return .loading
        }
    }
}

extension WalletListAssetViewModelFactory: WalletListAssetViewModelFactoryProtocol {
    func createGroupViewModel(
        for chain: ChainModel,
        assets: [WalletListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> WalletListGroupViewModel {
        let assetViewModels = assets.map { asset in
            createAssetViewModel(
                chainId: chain.chainId,
                assetAccountInfo: asset,
                connected: connected,
                locale: locale
            )
        }

        let networkName = chain.name.uppercased()

        let iconViewModel = RemoteImageViewModel(url: chain.icon)

        let priceString = priceFormatter.value(for: locale).stringFromDecimal(value) ?? ""

        let color: GradientModel

        if
            let colorString = chain.color,
            let colorModel = cssColorFactory.createFromString(colorString) {
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
        chainId: ChainModel.Id,
        assetAccountInfo: WalletListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> WalletListAssetViewModel {
        let priceState = createPriceState(assetAccountInfo: assetAccountInfo, locale: locale)

        let (balanceState, balanceValueState) = createBalanceState(
            assetAccountInfo: assetAccountInfo,
            connected: connected,
            locale: locale
        )

        let assetInfo = assetAccountInfo.assetInfo

        let iconViewModel = assetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return WalletListAssetViewModel(
            chainAssetId: ChainAssetId(chainId: chainId, assetId: assetAccountInfo.assetId),
            tokenName: assetInfo.symbol,
            icon: iconViewModel,
            price: priceState,
            balanceAmount: balanceState,
            balanceValue: balanceValueState
        )
    }
}
