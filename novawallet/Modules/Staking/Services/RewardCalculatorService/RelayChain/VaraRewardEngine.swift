import Foundation
import BigInt
import SubstrateSdk

// Implementation based on inflation from https://github.com/gear-tech/gear/blob/master/pallets/staking-rewards/src/lib.rs#L397
final class VaraRewardEngine: RewardCalculatorEngine {
    let annualInflation: BigUInt

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        annualInflation: BigUInt,
        totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) {
        self.annualInflation = annualInflation

        super.init(
            chainId: chainId,
            assetPrecision: assetPrecision,
            totalIssuance: totalIssuance,
            validators: validators,
            eraDurationInSeconds: eraDurationInSeconds
        )
    }

    override func calculateAnnualInflation() -> Decimal {
        Decimal.fromSubstrateQuintill(value: annualInflation) ?? 0
    }

    override func calculateEraReturn(from annualReturn: Decimal) -> Decimal {
        let daysInYear = TimeInterval(CalculationPeriod.year.inDays)
        let erasInYear = daysInYear * TimeInterval.secondsInDay / eraDurationInSeconds

        guard erasInYear > 0 else {
            return 0
        }

        return annualReturn / Decimal(erasInYear)
    }
}
