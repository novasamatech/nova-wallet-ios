import Foundation
import BigInt

protocol ParaStkValidatorFactoryProtocol: CollatorStakingValidatorFactoryProtocol {
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

    func notRevokingWhileStakingMore(
        collator: AccountId?,
        scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        locale: Locale
    ) -> DataValidating

    func isActiveCollator(
        for metadata: ParachainStaking.CandidateMetadata?,
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

extension ParaStkValidatorFactoryProtocol {
    func notExceedsMaxCollatorsForDelegator(
        _ delegator: ParachainStaking.Delegator?,
        selectedCollator: AccountId?,
        maxCollatorsAllowed: UInt32?,
        locale: Locale
    ) -> DataValidating {
        let currentCollators = delegator.map { Set($0.delegations.map(\.owner)) }

        return notExceedsMaxCollators(
            currentCollators: currentCollators,
            selectedCollator: selectedCollator,
            maxCollatorsAllowed: maxCollatorsAllowed,
            locale: locale
        )
    }
}
