import Foundation

protocol GovernanceDelegateConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveDelegate(viewModel: GovernanceDelegateStackCell.Model)
    func didReceiveTracks(viewModel: GovernanceTracksViewModel)
    func didReceiveYourDelegation(viewModel: GovernanceYourDelegationViewModel)
    func didReceiveTransferableAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveUndelegatingPeriod(viewModel: String)
    func didReceiveHints(viewModel: [String])
}

protocol GovernanceDelegateConfirmPresenterProtocol: AnyObject {
    func setup()
    func presentSenderAccount()
    func presentDelegateAccount()
    func presentTracks()
    func confirm()
}

protocol GovernanceDelegateConfirmInteractorInputProtocol: GovernanceDelegateInteractorInputProtocol,
    MultiExtrinsicSubmitRetryInputProtocol {
    func submit(actions: [GovernanceDelegatorAction])
}

protocol GovernanceDelegateConfirmInteractorOutputProtocol: GovernanceDelegateInteractorOutputProtocol {
    func didReceiveLocks(_ locks: AssetLocks)
    func didReceiveSubmissionResult(_ result: SubmitIndexedExtrinsicResult)
    func didReceiveError(_ error: GovernanceDelegateConfirmInteractorError)
}

protocol GovernanceDelegateConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    MessageSheetPresentable, AddressOptionsPresentable, GovernanceErrorPresentable, MultiExtrinsicRetryable {
    func showTracks(from view: GovernanceDelegateConfirmViewProtocol?, tracks: [GovernanceTrackInfoLocal])
    func complete(on view: GovernanceDelegateConfirmViewProtocol?, locale: Locale)
    func skip(on view: GovernanceDelegateConfirmViewProtocol?)
}
