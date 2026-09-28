import Foundation
import BigInt

struct SubtensorDelegateSelectionInfo {
    let accountId: AccountId
    let take: UInt16
    let identity: AccountIdentity?
    let rootOwnStake: Balance
    let rootDelegatorsStake: Balance
    let rootDelegatorCount: UInt32
    let minStake: Balance
    let hasValidatorPermits: Bool
}

extension SubtensorDelegateSelectionInfo {
    init(
        delegate: SubtensorDelegate,
        minStake: Balance
    ) {
        let rootStakes: [(AccountId, Balance)] = delegate.info.nominators.compactMap { nomination in
            let rootStake = nomination.stakes
                .filter { $0.netuid == SubtensorStakingPallet.rootNetuid }
                .reduce(Balance.zero) { $0 + $1.stake }

            guard rootStake > 0 else {
                return nil
            }

            return (nomination.nominator, rootStake)
        }

        let totalRootStake = rootStakes.reduce(Balance.zero) { $0 + $1.1 }
        let ownRootStake = rootStakes
            .filter { $0.0 == delegate.info.ownerSs58 }
            .reduce(Balance.zero) { $0 + $1.1 }

        self.init(
            accountId: delegate.info.delegateSs58,
            take: delegate.info.take,
            identity: delegate.identity,
            rootOwnStake: ownRootStake,
            rootDelegatorsStake: totalRootStake.subtractOrZero(ownRootStake),
            rootDelegatorCount: UInt32(clamping: rootStakes.count),
            minStake: minStake,
            hasValidatorPermits: delegate.info.validatorPermitNetuids.contains(SubtensorStakingPallet.rootNetuid)
        )
    }
}

extension SubtensorDelegateSelectionInfo: CollatorStakingSelectionInfoProtocol {
    var minRewardableStake: Balance { minStake }
    var apr: Decimal? { nil }
    var totalStake: Balance { rootOwnStake + rootDelegatorsStake }
    var ownStake: Balance? { rootOwnStake }
    var delegatorsStake: Balance { rootDelegatorsStake }
    var maxRewardedDelegations: UInt32 { rootDelegatorCount }
    var delegationCount: UInt32 { rootDelegatorCount }
    var isElected: Bool { hasValidatorPermits }

    func status(
        for _: AccountId,
        delegatorModel: CollatorStakingDelegator?,
        stake _: Balance
    ) -> CollatorStakingDelegationStatus {
        guard delegatorModel?.hasDelegation(to: accountId) == true else {
            return .notElected
        }

        return isElected ? .rewarded : .notRewarded
    }
}
