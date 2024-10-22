import Foundation
import SoraFoundation
import BigInt
import Operation_iOS

struct AssetListAssetAccountInfo {
    let assetId: AssetModel.Id
    let assetInfo: AssetBalanceDisplayInfo
    let balance: BigUInt?
    let priceData: PriceData?
}

protocol AssetListAssetViewModelFactoryProtocol {
    func createNetworkGroupViewModel(
        for chain: ChainModel,
        assets: [AssetListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> AssetListNetworkGroupViewModel

    func createTokenGroupViewModel(
        assetsListDiff: ListDifferenceCalculator<AssetListAssetModel>,
        group: AssetListAssetGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        connected: Bool,
        locale: Locale
    ) -> AssetListTokenGroupViewModel?

    func createTokenGroupAssetViewModel(
        assetModel: AssetListAssetModel,
        maybePrices: [ChainAssetId: PriceData]?,
        connected: Bool,
        locale: Locale
    ) -> AssetListTokenGroupAssetViewModel?

    func createNetworkGroupAssetViewModel(
        chainId: ChainModel.Id,
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> AssetListNetworkGroupAssetViewModel
}

class AssetListAssetViewModelFactory {
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>

    private(set) lazy var cssColorFactory = CSSGradientFactory()

    init(
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.assetFormatterFactory = assetFormatterFactory
        self.percentFormatter = percentFormatter
        self.currencyManager = currencyManager
    }

    func createBalanceViewModel(
        for assets: [AssetListAssetAccountInfo],
        group: AssetListAssetGroupModel,
        connected: Bool,
        locale: Locale
    ) -> AssetListAssetBalanceViewModel? {
        guard let assetInfo = assets.first?.assetInfo else {
            return nil
        }

        let totalBalance = assets.reduce(into: BigUInt()) { $0 += $1.balance ?? 0 }

        let totalInfo = AssetListAssetAccountInfo(
            assetId: 0,
            assetInfo: assetInfo,
            balance: group.amount.toSubstrateAmount(precision: assetInfo.assetPrecision),
            priceData: assets.first?.priceData
        )

        return createBalanceViewModel(
            using: totalInfo,
            connected: connected,
            locale: locale
        )
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
                let balanceValue = balanceViewModelFactory.priceFromAmount(
                    decimalBalance,
                    priceData: priceData
                ).value(for: locale)
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
            let priceData = assetAccountInfo.priceData,
            let price = Decimal(string: priceData.price) {
            let priceChangeValue = (assetAccountInfo.priceData?.dayChange ?? 0.0) / 100.0
            let priceChangeString = percentFormatter.value(for: locale)
                .stringFromDecimal(priceChangeValue) ?? ""
            let priceAssetInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: priceData.currencyId)
            let priceFormatter = assetFormatterFactory.createAssetPriceFormatter(for: priceAssetInfo).value(for: locale)
            let priceString = priceFormatter.stringFromDecimal(price) ?? ""

            let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
                ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
            return .loaded(value: AssetPriceViewModel(amount: priceString, change: priceChange))
        } else {
            return .loading
        }
    }

    func formatPrice(amount: Decimal, priceData: PriceData?, locale: Locale) -> String {
        let currencyId = priceData?.currencyId ?? currencyManager.selectedCurrency.id
        let assetDisplayInfo = priceAssetInfoFactory.createAssetBalanceDisplayInfo(from: currencyId)
        let priceFormatter = assetFormatterFactory.createAssetPriceFormatter(for: assetDisplayInfo)
        return priceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
    }
}

extension AssetListAssetViewModelFactory: AssetListAssetViewModelFactoryProtocol {
    func createNetworkGroupViewModel(
        for chain: ChainModel,
        assets: [AssetListAssetAccountInfo],
        value: Decimal,
        connected: Bool,
        locale: Locale
    ) -> AssetListNetworkGroupViewModel {
        let assetViewModels = assets.map { asset in
            createNetworkGroupAssetViewModel(
                chainId: chain.chainId,
                assetAccountInfo: asset,
                connected: connected,
                locale: locale
            )
        }

        let networkName = chain.name.uppercased()

        let iconViewModel = ImageViewModelFactory.createChainIconOrDefault(from: chain.icon)

        let priceString = formatPrice(
            amount: value,
            priceData: assets.first?.priceData,
            locale: locale
        )

        return AssetListNetworkGroupViewModel(
            networkName: networkName,
            amount: .loaded(value: priceString),
            icon: iconViewModel,
            assets: assetViewModels
        )
    }

    func createTokenGroupViewModel(
        assetsListDiff: ListDifferenceCalculator<AssetListAssetModel>,
        group: AssetListAssetGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        connected: Bool,
        locale: Locale
    ) -> AssetListTokenGroupViewModel? {
        let allAssets = assetsListDiff.allItems

        let allAssetsInfo = allAssets.map {
            AssetListPresenterHelpers.createAssetAccountInfo(
                from: $0,
                chain: $0.chainAssetModel.chain,
                maybePrices: maybePrices
            )
        }

        guard
            let token = allAssets.first,
            let balanceViewModel = createBalanceViewModel(
                for: allAssetsInfo,
                group: group,
                connected: connected,
                locale: locale
            ) else {
            return nil
        }

        let assetViewModels = allAssets.compactMap { assetModel in
            createTokenGroupAssetViewModel(
                assetModel: assetModel,
                maybePrices: maybePrices,
                connected: connected,
                locale: locale
            )
        }

        let tokenViewModel = AssetViewModel(
            symbol: token.chainAssetModel.asset.symbol,
            imageViewModel: ImageViewModelFactory.createAssetIconOrDefault(
                from: token.chainAssetModel.asset.icon
            )
        )

        return AssetListTokenGroupViewModel(
            token: tokenViewModel,
            assets: assetViewModels,
            balance: balanceViewModel
        )
    }

    func createNetworkGroupAssetViewModel(
        chainId: ChainModel.Id,
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> AssetListNetworkGroupAssetViewModel {
        let balanceViewModel = createBalanceViewModel(
            using: assetAccountInfo,
            connected: connected,
            locale: locale
        )

        let assetInfo = assetAccountInfo.assetInfo

        let iconViewModel = ImageViewModelFactory.createAssetIconOrDefault(from: assetInfo.icon)

        return AssetListNetworkGroupAssetViewModel(
            chainAssetId: ChainAssetId(chainId: chainId, assetId: assetAccountInfo.assetId),
            tokenName: assetInfo.symbol,
            icon: iconViewModel,
            balance: balanceViewModel
        )
    }

    func createTokenGroupAssetViewModel(
        assetModel: AssetListAssetModel,
        maybePrices: [ChainAssetId: PriceData]?,
        connected: Bool,
        locale: Locale
    ) -> AssetListTokenGroupAssetViewModel? {
        let assetInfo = createAssetAccountInfo(
            from: assetModel,
            chain: assetModel.chainAssetModel.chain,
            maybePrices: maybePrices
        )

        let chainAssetViewModel = chainAssetViewModelFactory.createViewModel(
            from: assetModel.chainAssetModel
        )

        let balanceViewModel = createBalanceViewModel(
            using: assetInfo,
            connected: connected,
            locale: locale
        )

        return AssetListTokenGroupAssetViewModel(
            chainAssetId: assetModel.chainAssetModel.chainAssetId,
            chainAsset: chainAssetViewModel,
            balance: balanceViewModel
        )
    }
}

// MARK: Private

private extension AssetListAssetViewModelFactory {
    func createBalanceViewModel(
        using assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> AssetListAssetBalanceViewModel {
        let priceState = createPriceState(assetAccountInfo: assetAccountInfo, locale: locale)

        let (balanceState, balanceValueState) = createBalanceState(
            assetAccountInfo: assetAccountInfo,
            connected: connected,
            locale: locale
        )

        return AssetListAssetBalanceViewModel(
            price: priceState,
            balanceAmount: balanceState,
            balanceValue: balanceValueState
        )
    }

    func createAssetAccountInfo(
        from asset: AssetListAssetModel,
        chain: ChainModel,
        maybePrices: [ChainAssetId: PriceData]?
    ) -> AssetListAssetAccountInfo {
        let assetModel = asset.chainAssetModel.asset
        let chainAssetId = ChainAssetId(chainId: chain.chainId, assetId: assetModel.assetId)

        let assetInfo = assetModel.displayInfo

        let priceData: PriceData?

        if let prices = maybePrices {
            priceData = prices[chainAssetId] ?? PriceData.zero()
        } else {
            priceData = nil
        }

        return AssetListAssetAccountInfo(
            assetId: asset.chainAssetModel.asset.assetId,
            assetInfo: assetInfo,
            balance: asset.totalAmount,
            priceData: priceData
        )
    }
}
