import Foundation
import BigInt
import SubstrateSdk

final class PolkadotRewardEngine: RewardCalculatorEngine {
    // Amount allocated to stakers in the last completed era, as reported by the staking
    // pallet's `era_reward_allocation` view function (mirrors `Staking.ErasValidatorReward`).
    //
    // After the Dynamic Allocation Pool (DAP) reform the network no longer mints the whole
    // period issuance to stakers: of the ~153,132 DOT minted per day only the staker allocation
    // (currently 45.2% ≈ 69,216 DOT/day) is paid out to stakers — the rest goes to the
    // validator incentive and the DAP buffer. Reading the recorded era allocation keeps the APY
    // correct without hardcoding the split: it tracks both the issuance curve (ref 1710) and any
    // future governance re-allocation of the DAP budget.
    let stakersEraReward: BigUInt

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        stakersEraReward: BigUInt,
        totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval
    ) {
        self.stakersEraReward = stakersEraReward

        super.init(
            chainId: chainId,
            assetPrecision: assetPrecision,
            totalIssuance: totalIssuance,
            validators: validators,
            eraDurationInSeconds: eraDurationInSeconds
        )
    }

    override func calculateAnnualInflation() -> Decimal {
        let eraStakersReward = Decimal.fromSubstrateAmount(
            stakersEraReward,
            precision: assetPrecision
        ) ?? 0

        guard totalIssuance > 0, eraDurationInSeconds > 0 else {
            return 0
        }

        let daysInYear = TimeInterval(CalculationPeriod.year.inDays)
        let erasInYear = daysInYear * TimeInterval.secondsInDay / eraDurationInSeconds

        // Expressed relative to total issuance because the base engine divides the result by
        // `stakedPortion` (= totalStake / totalIssuance) in `calculateReturnForStake`. Issuance
        // therefore cancels and the effective staker return reduces to
        // `stakersEraReward * erasInYear / totalStake`.
        let inflationPerEra = eraStakersReward / totalIssuance

        return inflationPerEra * Decimal(erasInYear)
    }

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
