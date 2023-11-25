import Foundation
import BigInt
import SoraFoundation

struct RateParams {
    let assetDisplayInfoIn: AssetBalanceDisplayInfo
    let assetDisplayInfoOut: AssetBalanceDisplayInfo
    let amountIn: BigUInt
    let amountOut: BigUInt
}

protocol SwapBaseViewModelFactoryProtocol {
    func rateViewModel(from params: RateParams, locale: Locale) -> String

    func priceDifferenceViewModel(
        rateParams: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?,
        locale: Locale
    ) -> DifferenceViewModel?

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
    let percentForamatter: LocalizableResource<NumberFormatter>
    let priceDifferenceConfig: SwapPriceDifferenceConfig

    init(
        balanceViewModelFactoryFacade: BalanceViewModelFactoryFacadeProtocol,
        percentForamatter: LocalizableResource<NumberFormatter>,
        priceDifferenceConfig: SwapPriceDifferenceConfig
    ) {
        self.balanceViewModelFactoryFacade = balanceViewModelFactoryFacade
        self.percentForamatter = percentForamatter
        self.priceDifferenceConfig = priceDifferenceConfig
    }

    func formatPriceDifference(amount: Decimal, locale: Locale) -> String {
        percentForamatter.value(for: locale).stringFromDecimal(amount) ?? ""
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

    func priceDifferenceViewModel(
        rateParams params: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?,
        locale: Locale
    ) -> DifferenceViewModel? {
        guard let priceIn = priceIn?.decimalRate, let priceOut = priceOut?.decimalRate else {
            return nil
        }

        guard
            let amountOutDecimal = Decimal.fromSubstrateAmount(
                params.amountOut,
                precision: params.assetDisplayInfoOut.assetPrecision
            ),
            let amountInDecimal = Decimal.fromSubstrateAmount(
                params.amountIn,
                precision: params.assetDisplayInfoIn.assetPrecision
            ) else {
            return nil
        }

        let amountPriceIn = amountInDecimal * priceIn
        let amountPriceOut = amountOutDecimal * priceOut

        guard amountPriceIn > 0, amountPriceOut > 0, amountPriceIn > amountPriceOut else {
            return nil
        }

        let diff = abs(amountPriceIn - amountPriceOut) / amountPriceIn
        let diffString = formatPriceDifference(amount: diff, locale: locale)

        switch diff {
        case _ where diff >= priceDifferenceConfig.high:
            return .init(details: diffString, attention: .high)
        case priceDifferenceConfig.medium ... priceDifferenceConfig.high:
            return .init(details: diffString, attention: .medium)
        case priceDifferenceConfig.low ... priceDifferenceConfig.medium:
            return .init(details: diffString, attention: .low)
        default:
            return nil
        }
    }
}
