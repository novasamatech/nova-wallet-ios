import Foundation

protocol MythosStakingRedeemInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func submit()
}

protocol MythosStakingRedeemInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveReleaseQueue(_ releaseQueue: MythosStakingPallet.ReleaseQueue?)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber)
    func didReceiveFrozen(_ frozenBalance: MythosStakingFrozenBalance)
    func didReceiveFeeResult(_ result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceiveSubmissionResult(_ result: Result<ExtrinsicSubmittedModel, Error>)
}

protocol MythosStakingRedeemWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, FeeRetryable,
    AddressOptionsPresentable,
    MythosStakingErrorPresentable,
    MessageSheetPresentable,
    ExtrinsicSubmissionPresenting, ExtrinsicSigningErrorHandling {
    func complete(
        view: CollatorStakingRedeemViewProtocol?,
        redeemedAll: Bool,
        locale: Locale
    )
}
