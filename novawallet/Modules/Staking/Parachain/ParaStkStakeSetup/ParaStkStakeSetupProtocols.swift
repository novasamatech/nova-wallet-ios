import Foundation
import BigInt

protocol ParaStkStakeSetupInteractorInputProtocol: AnyObject {
    func setup()

    func applyCollator(with accountId: AccountId)
    func estimateFee(with callWrapper: DelegationCallWrapper)
}

protocol ParaStkStakeSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?)
    func didReceiveMinTechStake(_ minStake: BigUInt)
    func didReceiveMinDelegationAmount(_ amount: BigUInt)
    func didReceiveMaxDelegations(_ maxDelegations: UInt32)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceivePreferredCollator(_ collator: DisplayAddress?)
    func didReceiveError(_ error: Error)
}

protocol ParaStkStakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    ParachainStakingErrorPresentable, CollatorStakingDelegationSelectable {
    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: ParachainStaking.Delegator?
    )

    func showCollatorSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: CollatorStakingSelectDelegate
    )
}
