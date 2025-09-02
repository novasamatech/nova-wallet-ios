import Foundation

protocol SwapPriceDifferenceModelFactoryProtocol {
    func createModel(
        params: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?
    ) -> SwapDifferenceModel?
}

final class SwapPriceDifferenceModelFactory {
    let config: SwapPriceDifferenceConfig

    init(config: SwapPriceDifferenceConfig) {
        self.config = config
    }
}

extension SwapPriceDifferenceModelFactory: SwapPriceDifferenceModelFactoryProtocol {
    func createModel(
        params: RateParams,
        priceIn: PriceData?,
        priceOut: PriceData?
    ) -> SwapDifferenceModel? {
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

        switch diff {
        case _ where diff >= config.high:
            return SwapDifferenceModel(diff: diff, attention: .high)
        case config.medium ... config.high:
            return SwapDifferenceModel(diff: diff, attention: .medium)
        case config.low ... config.medium:
            return SwapDifferenceModel(diff: diff, attention: .low)
        default:
            return nil
        }
    }
}
