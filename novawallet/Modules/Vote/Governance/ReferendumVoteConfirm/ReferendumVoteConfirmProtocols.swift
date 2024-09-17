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

protocol ReferendumVoteConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func presentSenderDetails()
}

protocol ReferendumVoteConfirmInteractorInputProtocol: ReferendumVoteInteractorInputProtocol {
    func submit(vote: ReferendumVoteAction)
}

protocol ReferendumVoteConfirmInteractorOutputProtocol: ReferendumVoteInteractorOutputProtocol {
    func didReceiveLocks(_ locks: AssetLocks)
    func didReceiveVotingHash(_ hash: String)
    func didReceiveError(_ error: ReferendumVoteConfirmError)
}

protocol ReferendumVoteConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    MessageSheetPresentable, AddressOptionsPresentable,
    ExtrinsicSubmissionPresenting, GovernanceErrorPresentable, ExtrinsicSigningErrorHandling {}
