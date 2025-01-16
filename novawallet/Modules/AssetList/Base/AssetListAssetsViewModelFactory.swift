import Foundation
import Foundation_iOS
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
        assetsList: [AssetListAssetModel],
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
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol

    private(set) lazy var cssColorFactory = CSSGradientFactory()

    init(
        chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol,
        assetFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        percentFormatter: LocalizableResource<NumberFormatter>,
        assetIconViewModelFactory: AssetIconViewModelFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAssetViewModelFactory = chainAssetViewModelFactory
        self.priceAssetInfoFactory = priceAssetInfoFactory
        self.assetFormatterFactory = assetFormatterFactory
        self.percentFormatter = percentFormatter
        self.assetIconViewModelFactory = assetIconViewModelFactory
        self.currencyManager = currencyManager
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

    func createBalanceViewModel(
        for group: AssetListAssetGroupModel,
        assetInfo: AssetBalanceDisplayInfo,
        maybePrices: [ChainAssetId: PriceData]?,
        connected _: Bool,
        locale: Locale
    ) -> AssetListAssetBalanceViewModel {
        let priceData: PriceData? = {
            if let priceDataKey = group.multichainToken.instances.first(
                where: { maybePrices?[$0.chainAssetId] != nil }
            )?.chainAssetId {
                maybePrices?[priceDataKey]
            } else {
                nil
            }
        }()

        let totalInfo = AssetListAssetAccountInfo(
            assetId: 0,
            assetInfo: assetInfo,
            balance: group.amount.toSubstrateAmount(precision: assetInfo.assetPrecision),
            priceData: priceData
        )

        let priceState = createPriceState(
            assetAccountInfo: totalInfo,
            locale: locale
        )

        let (amountState, valueState) = createBalanceState(
            for: group.amount,
            value: group.value,
            assetDisplayInfo: assetInfo,
            priceData: priceData,
            locale: locale
        )

        return AssetListAssetBalanceViewModel(
            price: priceState,
            balanceAmount: amountState,
            balanceValue: valueState
        )
    }

    func createBalanceState(
        for balance: Decimal,
        value: Decimal,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> (LoadableViewModelState<String>, LoadableViewModelState<String>) {
        let balanceViewModelFactory = balanceViewModelFactory(assetInfo: assetDisplayInfo)
        let balanceFormatter = assetFormatterFactory.createDisplayFormatter(for: assetDisplayInfo)

        let balanceAmountString = balanceFormatter.value(for: locale).stringFromDecimal(
            balance
        ) ?? ""

        let balanceState = LoadableViewModelState.loaded(value: balanceAmountString)

        if let priceData {
            let balanceValue = balanceViewModelFactory.priceFromFiatAmount(
                value,
                currencyId: priceData.currencyId
            ).value(for: locale)

            return (balanceState, .loaded(value: balanceValue))
        } else {
            return (balanceState, .loading)
        }
    }

    func createBalanceState(
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        locale: Locale
    ) -> (LoadableViewModelState<String>, LoadableViewModelState<String>) {
        if let balance = assetAccountInfo.balance {
            let assetInfo = assetAccountInfo.assetInfo
            let balanceViewModelFactory = balanceViewModelFactory(assetInfo: assetInfo)

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

    func balanceViewModelFactory(assetInfo: AssetBalanceDisplayInfo) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
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
}

// MARK: AssetListAssetViewModelFactoryProtocol

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

        let priceString: String = if let asset = assets.first, let priceData = asset.priceData {
            balanceViewModelFactory(assetInfo: asset.assetInfo)
                .priceFromFiatAmount(value, currencyId: priceData.currencyId)
                .value(for: locale)
        } else {
            ""
        }

        return AssetListNetworkGroupViewModel(
            networkName: networkName,
            amount: .loaded(value: priceString),
            icon: iconViewModel,
            assets: assetViewModels
        )
    }

    func createTokenGroupViewModel(
        assetsList: [AssetListAssetModel],
        group: AssetListAssetGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        connected: Bool,
        locale: Locale
    ) -> AssetListTokenGroupViewModel? {
        guard let assetInfo = assetsList.first?.chainAssetModel.assetDisplayInfo else {
            return nil
        }

        let assetViewModels = assetsList.compactMap { assetModel in
            createTokenGroupAssetViewModel(
                assetModel: assetModel,
                maybePrices: maybePrices,
                connected: connected,
                locale: locale
            )
        }

        let tokenViewModel = AssetViewModel(
            symbol: group.multichainToken.symbol,
            imageViewModel: assetIconViewModelFactory.createAssetIconViewModel(
                for: group.multichainToken.icon
            )
        )

        let balanceViewModel = createBalanceViewModel(
            for: group,
            assetInfo: assetInfo,
            maybePrices: maybePrices,
            connected: connected,
            locale: locale
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

        let iconViewModel = assetIconViewModelFactory.createAssetIconViewModel(
            for: assetInfo.icon?.getPath(),
            defaultURL: assetInfo.icon?.getURL()
        )

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
