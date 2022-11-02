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
}

protocol GovernanceUnlockConfirmInteractorInputProtocol: GovernanceUnlockInteractorInputProtocol {
    func estimateFee(for actions: Set<GovernanceUnlockSchedule.Action>)
    func unlock(using actions: Set<GovernanceUnlockSchedule.Action>)
}

protocol GovernanceUnlockConfirmInteractorOutputProtocol: GovernanceUnlockInteractorOutputProtocol {
    func didReceiveBalance(_ assetBalance: AssetBalance?)
    func didReceiveLocks(_ locks: AssetLocks)
    func didReceiveUnlockHash(_ hash: String)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveError(_ error: GovernanceUnlockConfirmInteractorError)
}

protocol GovernanceUnlockConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable,
                                                    FeeRetryable, MessageSheetPresentable, AddressOptionsPresentable,
                                                    ExtrinsicSubmissionPresenting, GovernanceErrorPresentable  {}
