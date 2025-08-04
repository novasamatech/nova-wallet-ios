import Foundation
import BigInt

protocol ParaStkStakeConfirmInteractorInputProtocol: PendingExtrinsicInteracting {
    func setup()

    func estimateFee(with callWrapper: DelegationCallWrapper)

    func confirm(with callWrapper: DelegationCallWrapper)
}

protocol ParaStkStakeConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?)
    func didReceiveMinTechStake(_ minStake: BigUInt)
    func didReceiveMinDelegationAmount(_ amount: BigUInt)
    func didReceiveMaxDelegations(_ maxDelegations: UInt32)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveStakingDuration(_ duration: ParachainStakingDuration)
    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>)
    func didReceiveError(_ error: Error)
}

protocol ParaStkStakeConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(
        on view: CollatorStakingConfirmViewProtocol?,
        sender: ExtrinsicSenderResolution,
        locale: Locale
    )
}
