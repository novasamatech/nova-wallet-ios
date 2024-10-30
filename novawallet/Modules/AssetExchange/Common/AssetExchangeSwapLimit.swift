import Foundation

struct AssetExchangeSwapLimit {
    let direction: AssetConversion.Direction
    let amountIn: Balance
    let amountOut: Balance
    let slippage: BigRational
}
