import Foundation

extension SlippageConfig {
    static var subtensorStaking: SlippageConfig {
        .init(
            defaultSlippage: SubtensorSlippageTolerance.defaultTolerance,
            slippageTips: SubtensorSlippageTolerance.presets,
            minAvailableSlippage: BigRational(numerator: 1, denominator: 10000),
            maxAvailableSlippage: BigRational(numerator: 50, denominator: 100),
            smallSlippage: BigRational(numerator: 1, denominator: 1000),
            bigSlippage: BigRational(numerator: 3, denominator: 100)
        )
    }
}
