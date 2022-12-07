import Foundation

extension RewardCalculatorEngineProtocol {
    // We are solving equation to find era interest - x: yr * T = T * (1 + x)^t - T
    func solveExponential(
        for annualReturn: Decimal,
        eraDurationInSeconds: TimeInterval,
        daysInYear: TimeInterval
    ) -> Decimal {
        guard eraDurationInSeconds > 0 else {
            return 0
        }

        let erasInYear = daysInYear * TimeInterval.secondsInDay / eraDurationInSeconds

        guard erasInYear > 0 else {
            return 0
        }

        let rawAnnualReturn = (annualReturn as NSDecimalNumber).doubleValue
        let result = pow(rawAnnualReturn + 1.0, 1.0 / Double(erasInYear)) - 1.0
        return Decimal(result)
    }
}
