import Foundation
import BigInt

protocol ParaStkValidatorFactoryProtocol: BaseDataValidatingFactoryProtocol {
    func delegatorNotExist(
        delegator: ParachainStaking.Delegator?,
        locale: Locale
    ) -> DataValidating

    func canStakeTopDelegations(
        amount: Decimal?,
        collator: ParachainStaking.CandidateMetadata?,
        existingBond: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func canStakeBottomDelegations(
        amount: Decimal?,
        collator: ParachainStaking.CandidateMetadata?,
        existingBond: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func hasMinStake(
        amount: Decimal?,
        minTechStake: BigUInt?,
        locale: Locale
    ) -> DataValidating

    func notExceedsMaxCollators(
        delegator: ParachainStaking.Delegator?,
        maxCollatorsAllowed: UInt32?,
        locale: Locale
    ) -> DataValidating

    func notRevokingWhileStakingMore(
        collator: AccountId?,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        locale: Locale
    ) -> DataValidating

    func canUnstake(
        amount: Decimal?,
        staked: BigUInt?,
        from collator: AccountId?,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        locale: Locale
    ) -> DataValidating

    func willRemainTopStaker(
        unstakingAmount: Decimal?,
        staked: BigUInt?,
        collator: ParachainStaking.CandidateMetadata?,
        minDelegationParams: ParaStkMinDelegationParams,
        locale: Locale
    ) -> DataValidating

    func shouldUnstakeAll(
        unstakingAmount: Decimal?,
        staked: BigUInt?,
        minDelegationParams: ParaStkMinDelegationParams,
        locale: Locale
    ) -> DataValidating

    func canRedeem(
        amount: Decimal?,
        collators: Set<AccountId>?,
        locale: Locale
    ) -> DataValidating

    func canRebond(
        collator: AccountId,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        locale: Locale
    ) -> DataValidating
}
