import Foundation

protocol SwapPriceDifferenceViewModelFactoryProtocol {
    var localizedPercentForamatter: NumberFormatter { get }
    var priceDifferenceWarningRange: (start: Decimal, end: Decimal) { get }

    func priceDifferenceViewModel(
        rateParams: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?
    ) -> DifferenceViewModel?
}

extension SwapPriceDifferenceViewModelFactoryProtocol {
    func priceDifferenceViewModel(
        rateParams params: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?
    ) -> DifferenceViewModel? {
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
        guard let priceIn = priceIn?.decimalRate,
              let priceOut = priceOut?.decimalRate else {
            return nil
        }

        let amountPriceIn = amountInDecimal * priceIn
        let amountPriceOut = amountOutDecimal * priceOut

        guard amountPriceIn != 0, amountPriceIn > amountPriceOut else {
            return nil
        }

        let diff = abs(amountPriceIn - amountPriceOut) / amountPriceIn
        let diffString = localizedPercentForamatter.stringFromDecimal(diff)?.inParenthesis() ?? ""

        switch diff {
        case _ where diff > priceDifferenceWarningRange.end:
            return .init(details: diffString, attention: .high)
        case priceDifferenceWarningRange.start ..< priceDifferenceWarningRange.end:
            return .init(details: diffString, attention: .medium)
        default:
            return .init(details: diffString, attention: .low)
        }
    }
}
