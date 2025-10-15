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

struct AssetListNetworkGroupViewModelParams {
    let chain: ChainModel
    let assets: [AssetListAssetAccountInfo]
    let value: Decimal
    let connected: Bool

    init(
        chain: ChainModel,
        assets: [AssetListAssetAccountInfo],
        value: Decimal,
        connected: Bool
    ) {
        self.chain = chain
        self.assets = assets
        self.value = value
        self.connected = connected
    }
}

struct AssetListTokenGroupViewModelParams {
    let assetsList: [AssetListAssetModel]
    let group: AssetListAssetGroupModel
    let maybePrices: [ChainAssetId: PriceData]?
    let connected: Bool

    init(
        assetsList: [AssetListAssetModel],
        group: AssetListAssetGroupModel,
        maybePrices: [ChainAssetId: PriceData]?,
        connected: Bool
    ) {
        self.assetsList = assetsList
        self.group = group
        self.maybePrices = maybePrices
        self.connected = connected
    }
}

struct AssetListTokenGroupAssetViewModelParams {
    let assetModel: AssetListAssetModel
    let maybePrices: [ChainAssetId: PriceData]?
    let connected: Bool

    init(
        assetModel: AssetListAssetModel,
        maybePrices: [ChainAssetId: PriceData]?,
        connected: Bool
    ) {
        self.assetModel = assetModel
        self.maybePrices = maybePrices
        self.connected = connected
    }
}

struct AssetListNetworkGroupAssetViewModelParams {
    let chainId: ChainModel.Id
    let assetAccountInfo: AssetListAssetAccountInfo
    let connected: Bool

    init(
        chainId: ChainModel.Id,
        assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool
    ) {
        self.chainId = chainId
        self.assetAccountInfo = assetAccountInfo
        self.connected = connected
    }
}

protocol AssetListAssetViewModelFactoryProtocol {
    func createNetworkGroupViewModel(
        params: AssetListNetworkGroupViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListNetworkGroupViewModel

    func createTokenGroupViewModel(
        params: AssetListTokenGroupViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListTokenGroupViewModel?

    func createTokenGroupAssetViewModel(
        params: AssetListTokenGroupAssetViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListTokenGroupAssetViewModel?

    func createNetworkGroupAssetViewModel(
        params: AssetListNetworkGroupAssetViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListNetworkGroupAssetViewModel
}

class AssetListAssetViewModelFactory {
    let chainAssetViewModelFactory: ChainAssetViewModelFactoryProtocol
    let priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    let assetFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let percentFormatter: LocalizableResource<NumberFormatter>
    let assetIconViewModelFactory: AssetIconViewModelFactoryProtocol
    let currencyManager: CurrencyManagerProtocol

    lazy var formattingCache = AssetFormattingCache(factory: assetFormatterFactory)

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

// MARK: - Private

private extension AssetListAssetViewModelFactory {
    func createBalanceViewModel(
        using assetAccountInfo: AssetListAssetAccountInfo,
        connected: Bool,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListAssetBalanceViewModel {
        let priceState = createPriceState(assetAccountInfo: assetAccountInfo, locale: genericParams.locale)

        let (balanceState, balanceValueState) = createBalanceState(
            assetAccountInfo: assetAccountInfo,
            genericParams: genericParams,
            connected: connected
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
        genericParams: ViewModelFactoryGenericParams
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
            locale: genericParams.locale
        )

        let (amountState, valueState) = createBalanceState(
            for: group.amount,
            value: group.value,
            assetDisplayInfo: assetInfo,
            priceData: priceData,
            genericParams: genericParams
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
        genericParams: ViewModelFactoryGenericParams
    ) -> (
        LoadableViewModelState<SecuredViewModel<String>>,
        LoadableViewModelState<SecuredViewModel<String>>
    ) {
        let balanceViewModelFactory = balanceViewModelFactory(assetInfo: assetDisplayInfo)

        let balanceAmountString = formattingCache.formatDecimal(
            balance,
            info: assetDisplayInfo,
            locale: genericParams.locale
        )

        let loadedAmount: LoadableViewModelState<SecuredViewModel<String>> = .loaded(
            value: .wrapped(balanceAmountString, with: genericParams.privacyModeEnabled)
        )

        if let priceData {
            let balanceValue = balanceViewModelFactory.priceFromFiatAmount(
                value,
                currencyId: priceData.currencyId
            ).value(for: genericParams.locale)
            return (loadedAmount, .loaded(value: .wrapped(balanceValue, with: genericParams.privacyModeEnabled)))
        } else {
            return (loadedAmount, .loading)
        }
    }

    func createBalanceState(
        assetAccountInfo: AssetListAssetAccountInfo,
        genericParams: ViewModelFactoryGenericParams,
        connected: Bool
    ) -> (
        LoadableViewModelState<SecuredViewModel<String>>,
        LoadableViewModelState<SecuredViewModel<String>>
    ) {
        if let balance = assetAccountInfo.balance {
            let assetInfo = assetAccountInfo.assetInfo
            let balanceViewModelFactory = balanceViewModelFactory(assetInfo: assetInfo)

            let decimalBalance = Decimal.fromSubstrateAmount(
                balance,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let balanceAmountString = formattingCache.formatDecimal(
                decimalBalance,
                info: assetInfo,
                locale: genericParams.locale
            )

            let loadedAmount: LoadableViewModelState<SecuredViewModel<String>> = connected
                ? .loaded(value: .wrapped(balanceAmountString, with: genericParams.privacyModeEnabled))
                : .cached(value: .wrapped(balanceAmountString, with: genericParams.privacyModeEnabled))

            if let priceData = assetAccountInfo.priceData {
                let balanceValue = balanceViewModelFactory.priceFromAmount(
                    decimalBalance,
                    priceData: priceData
                ).value(for: genericParams.locale)
                return (loadedAmount, .loaded(value: .wrapped(balanceValue, with: genericParams.privacyModeEnabled)))
            } else {
                return (loadedAmount, .loading)
            }

        } else {
            return (.loading, .loading)
        }
    }

    func balanceViewModelFactory(assetInfo: AssetBalanceDisplayInfo) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory,
            formattingCache: formattingCache
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

            let priceString = formattingCache.formatPrice(
                price,
                info: priceAssetInfo,
                locale: locale
            )

            let priceChange: ValueDirection<String> = priceChangeValue >= 0.0
                ? .increase(value: priceChangeString) : .decrease(value: priceChangeString)
            return .loaded(value: AssetPriceViewModel(amount: priceString, change: priceChange))
        } else {
            return .loading
        }
    }
}

// MARK: - AssetListAssetViewModelFactoryProtocol

extension AssetListAssetViewModelFactory: AssetListAssetViewModelFactoryProtocol {
    func createNetworkGroupViewModel(
        params: AssetListNetworkGroupViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListNetworkGroupViewModel {
        let assetViewModels = params.assets.map { asset in
            createNetworkGroupAssetViewModel(
                params: .init(
                    chainId: params.chain.chainId,
                    assetAccountInfo: asset,
                    connected: params.connected
                ),
                genericParams: genericParams
            )
        }

        let networkName = params.chain.name.uppercased()

        let iconViewModel = ImageViewModelFactory.createChainIconOrDefault(from: params.chain.icon)

        let priceString: String = if let asset = params.assets.first, let priceData = asset.priceData {
            balanceViewModelFactory(assetInfo: asset.assetInfo)
                .priceFromFiatAmount(params.value, currencyId: priceData.currencyId)
                .value(for: genericParams.locale)
        } else {
            ""
        }

        return AssetListNetworkGroupViewModel(
            networkName: networkName,
            amount: .wrapped(
                .loaded(value: priceString),
                with: genericParams.privacyModeEnabled
            ),
            icon: iconViewModel,
            assets: assetViewModels
        )
    }

    func createTokenGroupViewModel(
        params: AssetListTokenGroupViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListTokenGroupViewModel? {
        guard let assetInfo = params.assetsList.first?.chainAssetModel.assetDisplayInfo else {
            return nil
        }

        let assetViewModels = params.assetsList.compactMap { assetModel in
            createTokenGroupAssetViewModel(
                params: .init(
                    assetModel: assetModel,
                    maybePrices: params.maybePrices,
                    connected: params.connected
                ),
                genericParams: genericParams
            )
        }

        let tokenViewModel = AssetViewModel(
            symbol: params.group.multichainToken.symbol,
            imageViewModel: assetIconViewModelFactory.createAssetIconViewModel(
                for: params.group.multichainToken.icon
            )
        )

        let balanceViewModel = createBalanceViewModel(
            for: params.group,
            assetInfo: assetInfo,
            maybePrices: params.maybePrices,
            genericParams: genericParams
        )

        return AssetListTokenGroupViewModel(
            token: tokenViewModel,
            assets: assetViewModels,
            balance: balanceViewModel
        )
    }

    func createTokenGroupAssetViewModel(
        params: AssetListTokenGroupAssetViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListTokenGroupAssetViewModel? {
        let assetInfo = createAssetAccountInfo(
            from: params.assetModel,
            chain: params.assetModel.chainAssetModel.chain,
            maybePrices: params.maybePrices
        )

        let chainAssetViewModel = chainAssetViewModelFactory.createViewModel(
            from: params.assetModel.chainAssetModel
        )

        let balanceViewModel = createBalanceViewModel(
            using: assetInfo,
            connected: params.connected,
            genericParams: genericParams
        )

        return AssetListTokenGroupAssetViewModel(
            chainAssetId: params.assetModel.chainAssetModel.chainAssetId,
            chainAsset: chainAssetViewModel,
            balance: balanceViewModel
        )
    }

    func createNetworkGroupAssetViewModel(
        params: AssetListNetworkGroupAssetViewModelParams,
        genericParams: ViewModelFactoryGenericParams
    ) -> AssetListNetworkGroupAssetViewModel {
        let balanceViewModel = createBalanceViewModel(
            using: params.assetAccountInfo,
            connected: params.connected,
            genericParams: genericParams
        )

        let assetInfo = params.assetAccountInfo.assetInfo

        let iconViewModel = assetIconViewModelFactory.createAssetIconViewModel(
            for: assetInfo.icon?.getPath(),
            defaultURL: assetInfo.icon?.getURL()
        )

        return AssetListNetworkGroupAssetViewModel(
            chainAssetId: ChainAssetId(chainId: params.chainId, assetId: params.assetAccountInfo.assetId),
            tokenName: assetInfo.symbol,
            icon: iconViewModel,
            balance: balanceViewModel
        )
    }
}
