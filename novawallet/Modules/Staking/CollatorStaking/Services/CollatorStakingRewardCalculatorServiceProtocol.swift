import Foundation
import BigInt
import Operation_iOS

enum CollatorStkRewardCalculatorEngineError: Error {
    case missingCollator(_ collatorAccountId: AccountId)
}

protocol CollatorStakingRewardCalculatorEngineProtocol {
    var totalStaked: Balance { get }

    func calculateEarnings(
        amount: Decimal,
        collatorAccountId: AccountId,
        period: CalculationPeriod
    ) throws -> Decimal

    func calculateMaxEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal
}

extension CollatorStakingRewardCalculatorEngineProtocol {
    func calculateMaxReturn(for period: CalculationPeriod) -> Decimal {
        calculateMaxEarnings(amount: 1.0, period: period)
    }

    func calculateAPR(for collatorId: AccountId) throws -> Decimal {
        try calculateEarnings(amount: 1.0, collatorAccountId: collatorId, period: .year)
    }
}

protocol CollatorStakingRewardCalculatorServiceProtocol: ApplicationServiceProtocol {
    func fetchCalculatorOperation() -> BaseOperation<CollatorStakingRewardCalculatorEngineProtocol>
}
