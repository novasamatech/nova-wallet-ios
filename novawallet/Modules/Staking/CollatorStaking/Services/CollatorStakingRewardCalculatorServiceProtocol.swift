import Foundation
import BigInt
import Operation_iOS

protocol CollatorStakingRewardCalculatorEngineProtocol {
    var totalIssuance: BigUInt { get }
    var totalStaked: BigUInt { get }

    func calculateEarnings(
        amount: Decimal,
        collatorAccountId: AccountId,
        period: CalculationPeriod
    ) throws -> Decimal

    func calculateEarnings(
        amount: Decimal,
        collatorStake: BigUInt,
        period: CalculationPeriod
    ) throws -> Decimal

    func calculateMaxEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal

    func calculateAvgEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal
}

extension CollatorStakingRewardCalculatorEngineProtocol {
    func calculateMaxReturn(for period: CalculationPeriod) -> Decimal {
        calculateMaxEarnings(amount: 1.0, period: period)
    }

    func calculateAvgReturn(for period: CalculationPeriod) -> Decimal {
        calculateAvgEarnings(amount: 1.0, period: period)
    }

    func calculateAPR(for collatorId: AccountId) throws -> Decimal {
        try calculateEarnings(amount: 1.0, collatorAccountId: collatorId, period: .year)
    }

    func calculateAPR(for collatorStake: BigUInt) throws -> Decimal {
        try calculateEarnings(amount: 1.0, collatorStake: collatorStake, period: .year)
    }
}

protocol CollatorStakingRewardCalculatorServiceProtocol: ApplicationServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<CollatorStakingRewardCalculatorEngineProtocol>
}
