import Foundation

protocol ParaStkRedeemInteractorInputProtocol: PendingExtrinsicInteracting {
    func setup()
    func estimateFee(for collatorIds: Set<AccountId>)
    func submit(for collatorIds: Set<AccountId>)
}

protocol ParaStkRedeemInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceiveRoundInfo(_ roundInfo: ParachainStaking.RoundInfo?)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didCompleteExtrinsicSubmission(for result: Result<ExtrinsicSubmittedModel, Error>)
    func didReceiveError(_ error: Error)
}

protocol ParaStkRedeemWireframeProtocol: AlertPresentable, ErrorPresentable,
    ParachainStakingErrorPresentable,
    AddressOptionsPresentable,
    FeeRetryable,
    MessageSheetPresentable, ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {}
