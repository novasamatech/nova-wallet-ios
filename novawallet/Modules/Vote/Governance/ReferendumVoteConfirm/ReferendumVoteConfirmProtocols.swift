import Foundation

protocol ReferendumVoteConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(referendumNumber: String)
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveYourVote(viewModel: YourVoteRow.Model)
    func didReceiveTransferableAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockedPeriod(viewModel: ReferendumLockTransitionViewModel)
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
    ExtrinsicSubmissionPresenting {}
