import Foundation

struct AssetExchangeSwapLimit {
    let direction: AssetConversion.Direction
    let amountIn: Balance
    let amountOut: Balance
    let slippage: BigRational
}

extension AssetExchangeSwapLimit {
    private func getNewDirection(for shouldReplaceBuyWithSell: Bool) -> AssetConversion.Direction {
        switch direction {
        case .sell:
            .sell
        case .buy:
            shouldReplaceBuyWithSell ? .sell : .buy
        }
    }

    func replacingAmountIn(
        _ newAmountIn: Balance,
        shouldReplaceBuyWithSell: Bool
    ) -> AssetExchangeSwapLimit {
        let newAmountOut = (newAmountIn * amountOut) / amountIn
        let newDirection = getNewDirection(for: shouldReplaceBuyWithSell)

        return AssetExchangeSwapLimit(
            direction: newDirection,
            amountIn: newAmountIn,
            amountOut: newAmountOut,
            slippage: slippage
        )
    }
}
