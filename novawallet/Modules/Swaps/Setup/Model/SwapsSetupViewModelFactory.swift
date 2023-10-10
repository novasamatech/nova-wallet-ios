import SoraFoundation
import BigInt

struct RateParams {
    let assetDisplayInfoIn: AssetBalanceDisplayInfo
    let assetDisplayInfoOut: AssetBalanceDisplayInfo
    let amountIn: BigUInt
    let amountOut: BigUInt
}

protocol SwapsSetupViewModelFactoryProtocol {
    func buttonState(
        assetIn: ChainAssetId?,
        assetOut: ChainAssetId?,
        amountIn: Decimal?,
        amountOut: Decimal?
    ) -> ButtonState
    func payTitleViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo?,
        maxValue: BigUInt?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model
    func payAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel
    func inputPriceViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        amount: Decimal?,
        priceData: PriceData?,
        locale: Locale
    ) -> String?
    func receiveTitleViewModel(locale: Locale) -> TitleHorizontalMultiValueView.Model
    func receiveAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel
    func amountInputViewModel(chainAsset: ChainAsset, amount: Decimal?, locale: Locale) -> AmountInputViewModelProtocol
    func rateViewModel(from params: RateParams, locale: Locale) -> String
    func feeViewModel(
        amount: BigUInt,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        locale: Locale
    ) -> SwapFeeViewModel
}

final class SwapsSetupViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol
    let networkViewModelFactory: NetworkViewModelFactoryProtocol

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        networkViewModelFactory: NetworkViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
        self.networkViewModelFactory = networkViewModelFactory
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

    private func emptyPayAssetViewModel(locale: Locale) -> EmptySwapsAssetViewModel {
        EmptySwapsAssetViewModel(
            imageViewModel: StaticImageViewModel(image: R.image.iconAddSwapAmount()!),
            title: R.string.localizable.swapsSetupAssetPayTitle(preferredLanguages: locale.rLanguages),
            subtitle: R.string.localizable.swapsSetupAssetSelectSubtitle(preferredLanguages: locale.rLanguages)
        )
    }

    private func emptyReceiveAssetViewModel(locale: Locale) -> EmptySwapsAssetViewModel {
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
        maxValue: BigUInt?,
        locale: Locale
    ) -> TitleHorizontalMultiValueView.Model {
        let title = R.string.localizable.swapsSetupAssetSelectPayTitle(
            preferredLanguages: locale.rLanguages
        )

        if let assetDisplayInfo = assetDisplayInfo, let maxValue = maxValue {
            let amountDecimal = Decimal.fromSubstrateAmount(
                maxValue,
                precision: Int16(assetDisplayInfo.displayPrecision)
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

    func payAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel {
        chainAsset.map { .asset(assetViewModel(chainAsset: $0)) } ?? .empty(emptyPayAssetViewModel(locale: locale))
    }

    func inputPriceViewModel(
        assetDisplayInfo: AssetBalanceDisplayInfo,
        amount: Decimal?,
        priceData: PriceData?,
        locale: Locale
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

    func receiveTitleViewModel(locale: Locale) -> TitleHorizontalMultiValueView.Model {
        TitleHorizontalMultiValueView.Model(
            title:
            R.string.localizable.swapsSetupAssetSelectReceiveTitle(preferredLanguages: locale.rLanguages),
            subtitle: "",
            value: ""
        )
    }

    func receiveAssetViewModel(chainAsset: ChainAsset?, locale: Locale) -> SwapAssetInputViewModel {
        chainAsset.map { .asset(assetViewModel(chainAsset: $0)) } ?? .empty(emptyReceiveAssetViewModel(locale: locale))
    }

    func rateViewModel(from params: RateParams, locale: Locale) -> String {
        guard
            let amountOutDecimal = Decimal.fromSubstrateAmount(
                params.amountOut,
                precision: params.assetDisplayInfoOut.assetPrecision
            ),
            let amountInDecimal = Decimal.fromSubstrateAmount(
                params.amountIn,
                precision: params.assetDisplayInfoIn.assetPrecision
            ),
            amountInDecimal != 0 else {
            return ""
        }

        let difference = amountOutDecimal / amountInDecimal

        let amountIn = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoIn,
            value: 1
        ).value(for: locale)
        let amountOut = balanceViewModelFactoryFacade.amountFromValue(
            targetAssetInfo: params.assetDisplayInfoOut,
            value: difference ?? 0
        ).value(for: locale)

        return "\(amountIn) ≈ \(amountOut)"
    }

    func amountInputViewModel(
        chainAsset: ChainAsset,
        amount: Decimal?,
        locale: Locale
    ) -> AmountInputViewModelProtocol {
        balanceViewModelFactoryFacade.createBalanceInputViewModel(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            amount: amount
        ).value(for: locale)
    }

    func feeViewModel(
        amount: BigUInt,
        assetDisplayInfo: AssetBalanceDisplayInfo,
        priceData: PriceData?,
        locale: Locale
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

        // TODO: provide isEditable
        return .init(isEditable: false, balanceViewModel: balanceViewModel)
    }
}
