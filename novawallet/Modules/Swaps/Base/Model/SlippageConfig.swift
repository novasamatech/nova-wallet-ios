import Foundation

struct SlippageConfig {
    let defaultSlippage: BigRational
    let slippageTips: [BigRational]
    let minAvailableSlippage: BigRational
    let maxAvailableSlippage: BigRational
    let smallSlippage: BigRational
    let bigSlippage: BigRational
}

extension SlippageConfig {
    static var defaultConfig: SlippageConfig {
        .init(
            defaultSlippage: BigRational(numerator: 5, denominator: 1000),
            slippageTips: [
                BigRational(numerator: 1, denominator: 1000),
                BigRational(numerator: 5, denominator: 1000),
                BigRational(numerator: 1, denominator: 100)
            ],
            minAvailableSlippage: BigRational(numerator: 1, denominator: 10000),
            maxAvailableSlippage: BigRational(numerator: 50, denominator: 100),
            smallSlippage: BigRational(numerator: 5, denominator: 10000),
            bigSlippage: BigRational(numerator: 1, denominator: 100)
        )
    }
}
