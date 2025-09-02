import Foundation
import BigInt

/**
 * Implementation based on the following derivation:
 *
 * x - user stake
 * T - a particular collator's current total stake
 * Cn - number of collators
 * e - per-collator emission (in tokens)
 * E - total emission
 * user_yield - user yield per session, in %, for a particular collator
 *
 * e = E / Cn
 * staked_portion = x / (x + T)
 * user_yield (in %) = staked_portion * e / x = e / (x + T)
 *
 * We use min stake for x to not face enormous numbers when total stake in the system is close to zero
 */
final class MythosRewardCalculatorEngine {
    let totalStaked: BigUInt
    let aprByCollator: [AccountId: Decimal]
    let maxApr: Decimal?

    init(params: Params) {
        totalStaked = params.collators.reduce(0) { accum, collator in
            let stakeInCollator = collator.info?.stake ?? 0
            return accum + stakeInCollator
        }

        let yearlyEmission = Self.calculateYearlyEmission(for: params)

        let rewardableCollators = params.collators.filter(\.rewardable)
        let rewardableCollatorsCount = rewardableCollators.count

        let aprByCollator: [AccountId: Decimal] = rewardableCollators.reduce(into: [:]) { accum, collator in
            guard let stake = collator.info?.stake else {
                return
            }

            accum[collator.accountId] = Self.calculateApr(
                params: params,
                collatorStake: stake,
                yearlyEmission: yearlyEmission,
                rewardableCollatorsCount: rewardableCollatorsCount
            )
        }

        self.aprByCollator = aprByCollator
        maxApr = aprByCollator.values.max()
    }
}

extension MythosRewardCalculatorEngine {
    struct Params {
        let perBlockRewards: Balance
        let blockTime: BlockTime
        let collatorComission: Decimal
        let collators: MythosSessionCollators
        let minStake: Balance
        let asset: ChainAsset
    }
}

private extension MythosRewardCalculatorEngine {
    static func calculateYearlyEmission(for params: Params) -> Decimal {
        let daysInYear: TimeInterval = (CalculationPeriod.daysInYear as NSDecimalNumber).doubleValue
        let blocksFraction = daysInYear.secondsFromDays / params.blockTime.timeInterval
        let blocksPerYear = Decimal(blocksFraction.rounded(.down))

        return blocksPerYear * params.perBlockRewards.decimal(assetInfo: params.asset.assetDisplayInfo)
    }

    static func calculateApr(
        params: Params,
        collatorStake: Balance,
        yearlyEmission: Decimal,
        rewardableCollatorsCount: Int
    ) -> Decimal {
        let minStake = params.minStake.decimal(assetInfo: params.asset.assetDisplayInfo)
        let collatorStakeDecimal = collatorStake.decimal(assetInfo: params.asset.assetDisplayInfo)
        let perCollatorRewards = yearlyEmission / Decimal(rewardableCollatorsCount) * (1 - params.collatorComission)

        // We estimate rewards assuming user stakes at least min_stake - this will compute maximum possible APR
        // But at least not as big as when min stake not accounted
        return perCollatorRewards / (minStake + collatorStakeDecimal)
    }

    func calculateEarnings(for amount: Decimal, annualReturn: Decimal, period: CalculationPeriod) -> Decimal {
        let dailyReturn = annualReturn / CalculationPeriod.daysInYear
        return amount * dailyReturn * Decimal(period.inDays)
    }
}

extension MythosRewardCalculatorEngine: CollatorStakingRewardCalculatorEngineProtocol {
    func calculateEarnings(
        amount: Decimal,
        collatorAccountId: AccountId,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard let apr = aprByCollator[collatorAccountId] else {
            throw CollatorStkRewardCalculatorEngineError.missingCollator(collatorAccountId)
        }

        return calculateEarnings(for: amount, annualReturn: apr, period: period)
    }

    func calculateMaxEarnings(
        amount: Decimal,
        period: CalculationPeriod
    ) -> Decimal {
        guard let maxApr else {
            return 0
        }

        return calculateEarnings(for: amount, annualReturn: maxApr, period: period)
    }
}
