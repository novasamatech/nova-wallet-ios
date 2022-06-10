import Foundation

final class InflationCurveRewardEngine: RewardCalculatorEngine {
    private let decayRate: Decimal = 0.05

    // For all the cases we suggest that parachains are disabled
    // Thus, i_ideal = 0.1 and x_ideal = 0.75
    private let idealStakePortion: Decimal = 0.75
    private let idealInflation: Decimal = 0.1

    private let minimalInflation: Decimal = 0.025

    override func calculateAnnualInflation() -> Decimal {
        let idealInterest = idealInflation / idealStakePortion

        if stakedPortion <= idealStakePortion {
            return minimalInflation + stakedPortion * (idealInterest - minimalInflation / idealStakePortion)
        } else {
            let powerValue = (idealStakePortion - stakedPortion) / decayRate
            let doublePowerValue = Double(truncating: powerValue as NSNumber)
            let decayCoefficient = Decimal(pow(2, doublePowerValue))
            return minimalInflation + (idealInterest * idealStakePortion - minimalInflation) * decayCoefficient
        }
    }
}
