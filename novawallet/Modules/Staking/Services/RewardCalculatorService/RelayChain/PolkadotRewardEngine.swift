import Foundation
import BigInt
import SubstrateSdk

final class PolkadotRewardEngine: RewardCalculatorEngine {
    let inflationPrediction: RuntimeApiInflationPrediction

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        inflationPrediction: RuntimeApiInflationPrediction,
        totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) {
        self.inflationPrediction = inflationPrediction

        super.init(
            chainId: chainId,
            assetPrecision: assetPrecision,
            totalIssuance: totalIssuance,
            validators: validators,
            eraDurationInSeconds: eraDurationInSeconds
        )
    }

    override func calculateAnnualInflation() -> Decimal {
        guard let validatorsMint = inflationPrediction.nextMint.items.first else {
            return 0
        }

        let validatorsMintDecimal = Decimal.fromSubstrateAmount(
            validatorsMint,
            precision: assetPrecision
        ) ?? 0

        let daysInYear = TimeInterval(CalculationPeriod.year.inDays)
        let erasInYear = daysInYear * TimeInterval.secondsInDay / eraDurationInSeconds

        let inflationPerMint = validatorsMintDecimal / totalIssuance

        return inflationPerMint * Decimal(erasInYear)
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
