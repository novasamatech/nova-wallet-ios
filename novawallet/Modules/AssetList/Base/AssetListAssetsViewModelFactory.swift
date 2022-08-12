import Foundation
import SoraFoundation
import BigInt

struct AssetListAssetAccountInfo {
    let assetId: AssetModel.Id
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt?
    let priceData: PriceData?
}

protocol AssetListAssetViewModelFactoryProtocol {
    func createGroupViewModel(
        for chain: ChainModel,
        assets: [AssetListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> AssetListGroupViewModel

    func createAssetViewModel(
        chainId: ChainModel.Id,
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> AssetListAssetViewModel
}

class AssetListAssetViewModelFactory {
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>

    private(set) lazy var cssColorFactory = CSSGradientFactory()

    init(
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.assetFormatterFactory = assetFormatterFactory
        self.percentFormatter = percentFormatter
        self.currencyManager = currencyManager
    }

    func createBalanceState(
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> (LoadableViewModelState<String>, LoadableViewModelState<String>) {
        if let balance = assetAccountInfo.balance {
            let assetInfo = assetAccountInfo.assetInfo
            let balanceViewModelFactory = balanceViewModelFactory(assetAccountInfo: assetAccountInfo)

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

            if let priceData = assetAccountInfo.priceData {
                let balanceValue = balanceViewModelFactory.priceFromAmount(decimalBalance, priceData: priceData).value(for: locale)
                return (balanceState, .loaded(value: balanceValue))
            } else {
                return (balanceState, .loading)
            }

        } else {
            return (.loading, .loading)
        }
    }

    func balanceViewModelFactory(assetAccountInfo: AssetListAssetAccountInfo) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: assetAccountInfo.assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )
    }

    func createPriceState(
        assetAccountInfo: AssetListAssetAccountInfo,
        locale: Locale
    ) -> LoadableViewModelState<AssetPriceViewModel> {
        if
            let priceString = assetAccountInfo.priceData?.price,
            let price = Decimal(string: priceString) {
            let priceChangeValue = (assetAccountInfo.priceData?.dayChange ?? 0.0) / 100.0
            let priceChangeString = percentFormatter.value(for: locale)
                .stringFromDecimal(priceChangeValue) ?? ""
            let balanceViewModelFactory = balanceViewModelFactory(assetAccountInfo: assetAccountInfo)
            let priceString = balanceViewModelFactory.amountFromValue(price).value(for: locale)

            let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
                ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
            return .loaded(value: AssetPriceViewModel(amount: priceString, change: priceChange))
        } else {
            return .loading
        }
    }
}

extension AssetListAssetViewModelFactory: AssetListAssetViewModelFactoryProtocol {
    func createGroupViewModel(
        for chain: ChainModel,
        assets: [AssetListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> AssetListGroupViewModel {
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

        let priceString = formatPrice(
            amount: value,
            priceData: assets.first?.priceData,
            locale: locale
        )

        return AssetListGroupViewModel(
            networkName: networkName,
            amount: .loaded(value: priceString),
            icon: iconViewModel,
            assets: assetViewModels
        )
    }

    func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetFormatterFactory.createTokenFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }

    func createAssetViewModel(
        chainId: ChainModel.Id,
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> AssetListAssetViewModel {
        let priceState = createPriceState(assetAccountInfo: assetAccountInfo, locale: locale)

        let (balanceState, balanceValueState) = createBalanceState(
            assetAccountInfo: assetAccountInfo,
            connected: connected,
            locale: locale
        )

        let assetInfo = assetAccountInfo.assetInfo

        let iconViewModel = assetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return AssetListAssetViewModel(
            chainAssetId: ChainAssetId(chainId: chainId, assetId: assetAccountInfo.assetId),
            tokenName: assetInfo.symbol,
            icon: iconViewModel,
            price: priceState,
            balanceAmount: balanceState,
            balanceValue: balanceValueState
        )
    }
}
