import Foundation
import BigInt

final class AlephZeroRewardEngine: RewardCalculatorEngine {
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

    override func calculateReturnForStake(_: Decimal, commission: Decimal) -> Decimal {
        guard totalStake > 0 else {
            return 0
        }

        let annualInflation = calculateAnnualInflation()
        return (annualInflation / stakedPortion) * (1.0 - commission)
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
