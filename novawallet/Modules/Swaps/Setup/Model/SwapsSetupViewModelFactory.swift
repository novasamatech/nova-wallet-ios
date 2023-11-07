import SoraFoundation
import BigInt

struct RateParams {
    let assetDisplayInfoIn: AssetBalanceDisplayInfo
    let assetDisplayInfoOut: AssetBalanceDisplayInfo
    let amountIn: BigUInt
    let amountOut: BigUInt
}

protocol SwapsSetupViewModelFactoryProtocol: SwapPriceDifferenceViewModelFactoryProtocol {
    var locale: Locale { get set }

    func buttonState(
        assetIn: ChainAssetId?,
        assetOut: ChainAssetId?,
        amountIn: Decimal?,
        amountOut: Decimal?
    ) -> ButtonState
    func payTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        maxValue: BigUInt?
    ) -> TitleHorizontalMultiValueView.Model
    func payAssetViewModel(chainAsset: ChainAsset?) -> SwapAssetInputViewModel
    func inputPriceViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        amount: Decimal?,
        priceData: PriceData?
    ) -> String?
    func receiveTitleViewModel() -> TitleHorizontalMultiValueView.Model
    func receiveAssetViewModel(chainAsset: ChainAsset?) -> SwapAssetInputViewModel
    func amountInputViewModel(chainAsset: ChainAsset, amount: Decimal?) -> AmountInputViewModelProtocol
    func rateViewModel(from params: RateParams) -> String
    func feeViewModel(
        amount: BigUInt,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        isEditable: Bool,
        priceData: PriceData?
    ) -> SwapFeeViewModel

    func minimalBalanceSwapForFeeMessage(
        for networkFeeAddition: AssetConversion.AmountWithNative,
        feeChainAsset: ChainAsset,
        utilityChainAsset: ChainAsset,
        utilityPriceData: PriceData?
    ) -> String

    func amountFromValue(_ decimal: Decimal, chainAsset: ChainAsset) -> String
}

final class SwapsSetupViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol
    let percentForamatter: LocalizableResource<NumberFormatter>
    private(set) var localizedPercentForamatter: NumberFormatter
    private(set) var priceDifferenceWarningRange: (start: Decimal, end: Decimal) = (start: 0.1, end: 0.2)

    var locale: Locale {
        didSet {
            localizedPercentForamatter = percentForamatter.value(for: locale)
        }
    }

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol,
        percentForamatter: LocalizableResource<NumberFormatter>,
        locale: Locale
    ) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
        self.networkViewModelFactory = networkViewModelFactory
        self.percentForamatter = percentForamatter
        self.locale = locale
        localizedPercentForamatter = percentForamatter.value(for: locale)
    }

    private static func buttonTitle(
        assetIn: ChainAssetId?,
        assetOut: ChainAssetId?,
        amountIn: Decimal?,
        amountOut: Decimal?,
        locale: Locale
    ) -> String {
        switch (assetIn, assetOut) {
        case (nil, nil), (nil, _):
            return R.string.localizable.swapsSetupAssetActionSelectPay(preferredLanguages: locale.rLanguages)
        case (_, nil):
            return R.string.localizable.swapsSetupAssetActionSelectReceive(preferredLanguages: locale.rLanguages)
        default:
            if amountIn == nil || amountOut == nil {
                return R.string.localizable.swapsSetupAssetActionEnterAmount(preferredLanguages: locale.rLanguages)
            } else {
                return R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
            }
        }
    }

    private func assetViewModel(chainAsset: ChainAsset) -> SwapsAssetViewModel {
        let networkViewModel = networkViewModelFactory.createViewModel(from: chainAsset.chain)
        let assetIcon: ImageViewModelProtocol = chainAsset.asset.icon.map { RemoteImageViewModel(url: $0) } ??
            StaticImageViewModel(image: R.image.iconDefaultToken()!)

        return SwapsAssetViewModel(
            symbol: chainAsset.asset.symbol,
            imageViewModel: assetIcon,
            hub: networkViewModel
        )
    }

    private func emptyPayAssetViewModel() -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string.localizable.swapsSetupAssetPayTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.swapsSetupAssetSelectSubtitle(preferredLanguages: locale.rLanguages)
        )
    }

    private func emptyReceiveAssetViewModel() -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string.localizable.swapsSetupAssetReceiveTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.swapsSetupAssetSelectSubtitle(preferredLanguages: locale.rLanguages)
        )
    }
}

extension SwapsSetupViewModelFactory: SwapsSetupViewModelFactoryProtocol {
    func buttonState(
        assetIn: ChainAssetId?,
        assetOut: ChainAssetId?,
        amountIn: Decimal?,
        amountOut: Decimal?
    ) -> ButtonState {
        let dataFullFilled = assetIn != nil && assetOut != nil && amountIn != nil && amountOut != nil
        return .init(
            title: .init {
                Self.buttonTitle(
                    assetIn: assetIn,
                    assetOut: assetOut,
                    amountIn: amountIn,
                    amountOut: amountOut,
                    locale: $0
                )
            },
            enabled: dataFullFilled
        )
    }

    func payTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        maxValue: BigUInt?
    ) -> TitleHorizontalMultiValueView.Model {
        let title = R.string.localizable.swapsSetupAssetSelectPayTitle(
            preferredLanguages: locale.rLanguages
        )

        if let assetDisplayInfo = assetDisplayInfo, let maxValue = maxValue {
            let amountDecimal = Decimal.fromSubstrateAmount(
                maxValue,
                precision: Int16(assetDisplayInfo.assetPrecision)
            ) ?? 0
            let maxValueString = balanceViewModelFactoryFacade.amountFromValue(
                targetAssetInfo: assetDisplayInfo,
                value: amountDecimal
            ).value(for: locale)

            return .init(
                title: title,
                subtitle:
                R.string.localizable.swapsSetupAssetMax(
                    preferredLanguages: locale.rLanguages
                ),
                value: maxValueString
            )
        } else {
            return .init(
                title:
                R.string.localizable.swapsSetupAssetSelectPayTitle(
                    preferredLanguages: locale.rLanguages
                ),
                subtitle: "",
                value: ""
            )
        }
    }

    func payAssetViewModel(chainAsset: ChainAsset?) -> SwapAssetInputViewModel {
        chainAsset.map { .asset(assetViewModel(chainAsset: $0)) } ?? .empty(emptyPayAssetViewModel())
    }

    func inputPriceViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        amount: Decimal?,
        priceData: PriceData?
    ) -> String? {
        guard
            let amount = amount,
            let priceData = priceData else {
            return nil
        }
        return balanceViewModelFactoryFacade.priceFromAmount(
            targetAssetInfo: assetDisplayInfo,
            amount: amount,
            priceData: priceData
        ).value(for: locale)
    }

    func receiveTitleViewModel() -> TitleHorizontalMultiValueView.Model {
        TitleHorizontalMultiValueView.Model(
            title:
            R.string.localizable.swapsSetupAssetSelectReceiveTitle(preferredLanguages: locale.rLanguages),
            subtitle: "",
            value: ""
        )
    }

    func receiveAssetViewModel(chainAsset: ChainAsset?) -> SwapAssetInputViewModel {
        chainAsset.map { .asset(assetViewModel(chainAsset: $0)) } ?? .empty(emptyReceiveAssetViewModel())
    }

    func rateViewModel(from params: RateParams) -> String {
        guard
            let rate = Decimal.rateFromSubstrate(
                amount1: params.amountIn,
                amount2: params.amountOut,
                precision1: params.assetDisplayInfoIn.assetPrecision,
                precision2: params.assetDisplayInfoOut.assetPrecision
            ) else {
            return ""
        }

        let amountIn = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoIn,
            value: 1
        ).value(for: locale)
        let amountOut = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoOut,
            value: rate
        ).value(for: locale)

        return amountIn.estimatedEqual(to: amountOut)
    }

    func amountInputViewModel(
        chainAsset: ChainAsset,
        amount: Decimal?
    ) -> AmountInputViewModelProtocol {
        balanceViewModelFactoryFacade.createBalanceInputViewModel(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            amount: amount
        ).value(for: locale)
    }

    func feeViewModel(
        amount: BigUInt,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        isEditable: Bool,
        priceData: PriceData?
    ) -> SwapFeeViewModel {
        let amountDecimal = Decimal.fromSubstrateAmount(
            amount,
            precision: assetDisplayInfo.assetPrecision
        ) ?? 0
        let balanceViewModel = balanceViewModelFactoryFacade.balanceFromPrice(
            targetAssetInfo: assetDisplayInfo,
            amount: amountDecimal,
            priceData: priceData
        ).value(for: locale)

        return .init(isEditable: isEditable, balanceViewModel: balanceViewModel)
    }

    func minimalBalanceSwapForFeeMessage(
        for networkFeeAddition: AssetConversion.AmountWithNative,
        feeChainAsset: ChainAsset,
        utilityChainAsset: ChainAsset,
        utilityPriceData: PriceData?
    ) -> String {
        let targetAmount = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: feeChainAsset.assetDisplayInfo,
            value: networkFeeAddition.targetAmount.decimal(precision: feeChainAsset.asset.precision)
        ).value(for: locale)

        let nativeAmountDecimal = networkFeeAddition.nativeAmount.decimal(precision: utilityChainAsset.asset.precision)
        let nativeAmountWithoutPrice = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: utilityChainAsset.assetDisplayInfo,
            value: nativeAmountDecimal
        ).value(for: locale)

        let nativeAmount: String

        if let priceData = utilityPriceData {
            let price = balanceViewModelFactoryFacade.priceFromAmount(
                targetAssetInfo: utilityChainAsset.assetDisplayInfo,
                amount: nativeAmountDecimal,
                priceData: priceData
            ).value(for: locale)

            nativeAmount = "\(nativeAmountWithoutPrice) \(price.inParenthesis())"
        } else {
            nativeAmount = nativeAmountWithoutPrice
        }

        return R.string.localizable.swapsPayAssetFeeEdMessage(
            feeChainAsset.asset.symbol,
            targetAmount,
            nativeAmount,
            utilityChainAsset.asset.symbol,
            preferredLanguages: locale.rLanguages
        )
    }

    func amountFromValue(_ decimal: Decimal, chainAsset: ChainAsset) -> String {
        balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            value: decimal
        ).value(for: locale)
    }
}
