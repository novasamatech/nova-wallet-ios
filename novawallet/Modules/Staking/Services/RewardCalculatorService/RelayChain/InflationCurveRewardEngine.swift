import Foundation
import BigInt

final class InflationCurveRewardEngine: RewardCalculatorEngine {
    let config: InflationCurveRewardConfig
    let parachainsCount: Int

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval,
        config: InflationCurveRewardConfig,
        parachainsCount: Int
    ) {
        self.config = config
        self.parachainsCount = parachainsCount

        super.init(
            chainId: chainId,
            assetPrecision: assetPrecision,
            totalIssuance: totalIssuance,
            validators: validators,
            eraDurationInSeconds: eraDurationInSeconds
        )
    }

    override func calculateAnnualInflation() -> Decimal {
        let deltaAnnualInflation = config.maxAnnualInflation - config.minAnnualInflation
        let idealStakePortion = config.idealStakePortion(for: parachainsCount)

        let adjustment: Decimal
        if stakedPortion < idealStakePortion {
            adjustment = stakedPortion / idealStakePortion
        } else {
            let powerValue = (idealStakePortion - stakedPortion) / config.fallof
            let doublePowerValue = Double(truncating: powerValue as NSNumber)
            adjustment = Decimal(pow(2, doublePowerValue))
        }

        return config.minAnnualInflation + deltaAnnualInflation * adjustment
    }

    // We are solving equation to find era interest - x: yr * T = T * (1 + x)^t - T
    override func calculateEraReturn(from annualReturn: Decimal) -> Decimal {
        guard eraDurationInSeconds > 0 else {
            return 0
        }

        let daysInYear = TimeInterval(CalculationPeriod.year.inDays)
        let erasInYear = daysInYear * TimeInterval.secondsInDay / eraDurationInSeconds

        guard erasInYear > 0 else {
            return 0
        }

        let rawAnnualReturn = (annualReturn as NSDecimalNumber).doubleValue
        let result = pow(rawAnnualReturn + 1.0, 1.0 / Double(erasInYear)) - 1.0

        return Decimal(result)
    }
}
