import Foundation
import BigInt

final class UniformCurveRewardEngine: RewardCalculatorEngine {
    let issuancePerYear: Decimal
    let treasuryPercentage: Decimal

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval,
        issuancePerYear: Decimal,
        treasuryPercentage: Decimal
    ) {
        self.issuancePerYear = issuancePerYear
        self.treasuryPercentage = treasuryPercentage

        super.init(
            chainId: chainId,
            assetPrecision: assetPrecision,
            totalIssuance: totalIssuance,
            validators: validators,
            eraDurationInSeconds: eraDurationInSeconds
        )
    }

    override func calculateAnnualInflation() -> Decimal {
        guard totalIssuance > 0 else {
            return 0.0
        }

        return (1 - treasuryPercentage) * issuancePerYear / totalIssuance
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
