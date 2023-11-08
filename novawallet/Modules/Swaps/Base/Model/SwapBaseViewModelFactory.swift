import Foundation
import BigInt

struct RateParams {
    let assetDisplayInfoIn: AssetBalanceDisplayInfo
    let assetDisplayInfoOut: AssetBalanceDisplayInfo
    let amountIn: BigUInt
    let amountOut: BigUInt
}

protocol SwapBaseViewModelFactoryProtocol {
    func rateViewModel(from params: RateParams, locale: Locale) -> String

    func minimalBalanceSwapForFeeMessage(
        for networkFeeAddition: AssetConversion.AmountWithNative,
        feeChainAsset: ChainAsset,
        utilityChainAsset: ChainAsset,
        utilityPriceData: PriceData?,
        locale: Locale
    ) -> String
}

class SwapBaseViewModelFactory {
    let balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol

    init(balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
    }
}

extension SwapBaseViewModelFactory: SwapBaseViewModelFactoryProtocol {
    func rateViewModel(from params: RateParams, locale: Locale) -> String {
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

    func minimalBalanceSwapForFeeMessage(
        for networkFeeAddition: AssetConversion.AmountWithNative,
        feeChainAsset: ChainAsset,
        utilityChainAsset: ChainAsset,
        utilityPriceData: PriceData?,
        locale: Locale
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
}
