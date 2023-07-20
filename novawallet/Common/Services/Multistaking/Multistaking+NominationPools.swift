import Foundation
import SubstrateSdk
import BigInt

extension Multistaking {
    struct NominationPoolStateChange: BatchStorageSubscriptionResult {
        enum Key: String {
            case era
            case ledger
            case nomination
            case bonded
        }

        let ledger: UncertainStorage<StakingLedger?>
        let bondedPool: UncertainStorage<NominationPools.BondedPool?>
        let era: UncertainStorage<ActiveEraInfo>
        let nomination: UncertainStorage<Nomination?>

        init(
            values: [BatchStorageSubscriptionResultValue],
            blockHashJson _: JSON,
            context: [CodingUserInfoKey: Any]?
        ) throws {
            ledger = try UncertainStorage(
                values: values,
                localKey: Key.ledger.rawValue,
                context: context
            )

            nomination = try UncertainStorage(
                values: values,
                localKey: Key.nomination.rawValue,
                context: context
            )

            era = try UncertainStorage(
                values: values,
                localKey: Key.era.rawValue,
                context: context
            )

            bondedPool = try UncertainStorage(
                values: values,
                localKey: Key.bonded.rawValue,
                context: context
            )
        }
    }

    struct NominationPoolState {
        let poolMember: NominationPools.PoolMember
        let era: ActiveEraInfo?
        let ledger: StakingLedger?
        let nomination: Nomination?
        let bondedPool: NominationPools.BondedPool?

        var poolId: NominationPools.PoolId {
            poolMember.poolId
        }

        var poolMemberStake: BigUInt? {
            guard let bondedPool = bondedPool, let ledger = ledger else {
                return nil
            }

            return NominationPools.pointsToBalance(
                for: poolMember.points,
                totalPoints: bondedPool.points,
                poolBalance: ledger.active
            )
        }

        func applying(change: NominationPoolStateChange) -> NominationPoolState {
            let newEra: ActiveEraInfo?

            if case let .defined(activeEra) = change.era {
                newEra = activeEra
            } else {
                newEra = era
            }

            let newLedger = change.ledger.valueWhenDefined(else: ledger)
            let newNomination = change.nomination.valueWhenDefined(else: nomination)
            let newBondedPool = change.bondedPool.valueWhenDefined(else: bondedPool)

            return .init(
                poolMember: poolMember,
                era: newEra,
                ledger: newLedger,
                nomination: newNomination,
                bondedPool: newBondedPool
            )
        }

        func applying(newPoolMember: NominationPools.PoolMember) -> NominationPoolState {
            .init(
                poolMember: newPoolMember,
                era: era,
                ledger: ledger,
                nomination: nomination,
                bondedPool: bondedPool
            )
        }
    }
}
