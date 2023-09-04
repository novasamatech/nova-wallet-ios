import Foundation
import BigInt
import SubstrateSdk

struct PooledBalanceStateChange: BatchStorageSubscriptionResult {
    enum Key: String {
        case ledger
        case bonded
        case subpools
    }

    let ledger: UncertainStorage<StakingLedger?>
    let bondedPool: UncertainStorage<NominationPools.BondedPool?>
    let subPools: UncertainStorage<NominationPools.SubPools?>

    init(
        values: [BatchStorageSubscriptionResultValue],
        blockHashJson _: JSON,
        context: [CodingUserInfoKey: Any]?
    ) throws {
        ledger = try UncertainStorage(
            values: values,
            mappingKey: Key.ledger.rawValue,
            context: context
        )

        bondedPool = try UncertainStorage(
            values: values,
            mappingKey: Key.bonded.rawValue,
            context: context
        )

        subPools = try UncertainStorage(
            values: values,
            mappingKey: Key.subpools.rawValue,
            context: context
        )
    }
}

struct PooledBalanceState {
    let poolMember: NominationPools.PoolMember
    let ledger: StakingLedger?
    let bondedPool: NominationPools.BondedPool?
    let subPools: NominationPools.SubPools?

    var poolId: NominationPools.PoolId {
        poolMember.poolId
    }

    var totalStake: BigUInt? {
        guard let bondedPool = bondedPool, let ledger = ledger else {
            return nil
        }

        let activeStake = NominationPools.pointsToBalance(
            for: poolMember.points,
            totalPoints: bondedPool.points,
            poolBalance: ledger.active
        )

        let unbondingStake = subPools?.unbondingBalance(for: poolMember) ?? 0

        return activeStake + unbondingStake
    }

    func applying(change: PooledBalanceStateChange) -> PooledBalanceState {
        let newLedger = change.ledger.valueWhenDefined(else: ledger)
        let newBondedPool = change.bondedPool.valueWhenDefined(else: bondedPool)
        let newSubPools = change.subPools.valueWhenDefined(else: subPools)

        return .init(
            poolMember: poolMember,
            ledger: newLedger,
            bondedPool: newBondedPool,
            subPools: newSubPools
        )
    }

    func applying(newPoolMember: NominationPools.PoolMember) -> PooledBalanceState {
        .init(
            poolMember: newPoolMember,
            ledger: ledger,
            bondedPool: bondedPool,
            subPools: subPools
        )
    }
}
