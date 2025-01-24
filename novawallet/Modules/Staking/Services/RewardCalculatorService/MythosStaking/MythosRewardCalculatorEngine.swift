import Foundation
import BigInt

// TODO: Implement in separate task
final class MythosRewardCalculatorEngine {}

extension MythosRewardCalculatorEngine: CollatorStakingRewardCalculatorEngineProtocol {
    var totalIssuance: BigUInt { 0 }
    var totalStaked: BigUInt { 0 }

    func calculateEarnings(
        amount _: Decimal,
        collatorAccountId _: AccountId,
        period _: CalculationPeriod
    ) throws -> Decimal {
        0
    }

    func calculateEarnings(
        amount _: Decimal,
        collatorStake _: BigUInt,
        period _: CalculationPeriod
    ) throws -> Decimal {
        0
    }

    func calculateMaxEarnings(
        amount _: Decimal,
        period _: CalculationPeriod
    ) -> Decimal {
        0
    }

    func calculateAvgEarnings(
        amount _: Decimal,
        period _: CalculationPeriod
    ) -> Decimal {
        0
    }
}
