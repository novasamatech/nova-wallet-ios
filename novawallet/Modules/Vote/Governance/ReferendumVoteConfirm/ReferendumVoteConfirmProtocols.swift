import Foundation

protocol BaseReferendumVoteConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveTransferableAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockedPeriod(viewModel: ReferendumLockTransitionViewModel)
}

protocol ReferendumVoteConfirmViewProtocol: BaseReferendumVoteConfirmViewProtocol {
    func didReceive(referendumNumber: String)
    func didReceiveYourVote(viewModel: YourVoteRow.Model)
}

protocol BaseReferendumVoteConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func presentSenderDetails()
}

protocol ReferendumVoteConfirmPresenterProtocol: BaseReferendumVoteConfirmPresenterProtocol {}

protocol ReferendumVoteConfirmInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {
    func submit(vote: ReferendumNewVote)
}

protocol BaseReferendumVoteConfirmInteractorOutputProtocol: ReferendumVoteInteractorOutputProtocol,
    ReferendumObservingVoteInteractorOutputProtocol {
    func didReceiveLocks(_ locks: AssetLocks)
    func didReceiveError(_ error: ReferendumVoteConfirmError)
}

protocol ReferendumVoteConfirmInteractorOutputProtocol: BaseReferendumVoteConfirmInteractorOutputProtocol {
    func didReceiveVotingCompletion(_ sender: ExtrinsicSenderResolution)
}

protocol BaseReferendumVoteConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    MessageSheetPresentable, AddressOptionsPresentable,
    ExtrinsicSubmissionPresenting, GovernanceErrorPresentable, ExtrinsicSigningErrorHandling, ModalAlertPresenting {}

protocol ReferendumVoteConfirmWireframeProtocol: BaseReferendumVoteConfirmWireframeProtocol {}
