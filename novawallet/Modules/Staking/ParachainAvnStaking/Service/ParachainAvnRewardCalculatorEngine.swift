import Foundation
import BigInt

/// Reward calculator engine for Energy Web X staking.
///
/// EWX does not use Moonbeam's inflation-config model. Instead,
/// APR is computed from the on-chain `Growth` storage which
/// accumulates actual rewards per growth period:
///
///   APR = (totalStakerReward / totalStakeAccumulated)
///         * (365 / numberOfAccumulations)
///
/// Commission is global (`DefaultCollatorCommission`), not
/// per-collator. All collators receive the same commission rate.
final class ParachainAvnRewardCalculatorEngine {
    let annualApr: Decimal
    let commission: Decimal
    let totalStakedAmount: BigUInt
    let selectedCollators: SelectedRoundCollators
    let assetPrecision: Int16

    init(
        annualApr: Decimal,
        commission: Decimal,
        totalStakedAmount: BigUInt,
        selectedCollators: SelectedRoundCollators,
        assetPrecision: Int16
    ) {
        self.annualApr = annualApr
        self.commission = commission
        self.totalStakedAmount = totalStakedAmount
        self.selectedCollators = selectedCollators
        self.assetPrecision = assetPrecision
    }

    private lazy var averageStake: Decimal = {
        let count = selectedCollators.collators.count
        guard count > 0 else { return 0 }
        let total = selectedCollators.collators.reduce(BigUInt(0)) { $0 + $1.snapshot.total }
        return (Decimal.fromSubstrateAmount(total, precision: assetPrecision) ?? 0) / Decimal(count)
    }()

    private lazy var minStake: Decimal = {
        guard let minTotal = selectedCollators.collators.min(
            by: { $0.snapshot.total < $1.snapshot.total }
        )?.snapshot.total else { return 0 }
        return Decimal.fromSubstrateAmount(minTotal, precision: assetPrecision) ?? 0
    }()
}

extension ParachainAvnRewardCalculatorEngine: CollatorStakingRewardCalculatorEngineProtocol {
    var totalStaked: Balance { totalStakedAmount }

    func calculateEarnings(
        amount: Decimal,
        collatorAccountId: AccountId,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard selectedCollators.collators.contains(where: { $0.accountId == collatorAccountId }) else {
            throw CollatorStkRewardCalculatorEngineError.missingCollator(collatorAccountId)
        }

        let netApr = annualApr * (1 - commission)
        let dailyReturn = netApr / CalculationPeriod.daysInYear
        return amount * dailyReturn * Decimal(period.inDays)
    }

    func calculateMaxEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal {
        let netApr = annualApr * (1 - commission)
        let dailyReturn = netApr / CalculationPeriod.daysInYear
        return amount * dailyReturn * Decimal(period.inDays)
    }
}
