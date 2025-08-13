import BigInt

protocol GovernanceUnlockConfirmViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveAmount(viewModel: BalanceViewModelProtocol)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveAccount(viewModel: DisplayAddressViewModel)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveTransferableAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveLockedAmount(viewModel: ReferendumLockTransitionViewModel)
    func didReceiveRemainedLock(viewModel: GovernanceRemainedLockViewModel?)
}

protocol GovernanceUnlockConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func presentSenderDetails()
}

protocol GovernanceUnlockConfirmInteractorInputProtocol: GovernanceUnlockInteractorInputProtocol,
    MultiExtrinsicSubmitRetryInputProtocol {
    func estimateFee(for actions: Set<GovernanceUnlockSchedule.Action>)
    func unlock(using actions: Set<GovernanceUnlockSchedule.Action>)
}

protocol GovernanceUnlockConfirmInteractorOutputProtocol: GovernanceUnlockInteractorOutputProtocol {
    func didReceiveBalance(_ assetBalance: AssetBalance?)
    func didReceiveLocks(_ locks: AssetLocks)
    func didReceiveSubmissionResult(_ result: SubmitIndexedExtrinsicResult)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveError(_ error: GovernanceUnlockConfirmInteractorError)
}

protocol GovernanceUnlockConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
    FeeRetryable, MessageSheetPresentable, AddressOptionsPresentable,
    GovernanceErrorPresentable, ExtrinsicSigningErrorHandling, ModalAlertPresenting,
    ExtrinsicSubmissionPresenting, MultiExtrinsicRetryable {
    func skip(on view: GovernanceUnlockConfirmViewProtocol?)
}
