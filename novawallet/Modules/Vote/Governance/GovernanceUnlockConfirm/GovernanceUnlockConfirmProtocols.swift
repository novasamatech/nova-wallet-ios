import BigInt

protocol GovernanceUnlockConfirmViewProtocol: ControllerBackedProtocol {}

protocol GovernanceUnlockConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol GovernanceUnlockConfirmInteractorInputProtocol: GovernanceUnlockInteractorInputProtocol {
    func estimateFee(for actions: Set<GovernanceUnlockSchedule.Action>)
    func unlock(using actions: Set<GovernanceUnlockSchedule.Action>)
}

protocol GovernanceUnlockConfirmInteractorOutputProtocol: GovernanceUnlockInteractorOutputProtocol {
    func didReceiveLocks(_ locks: AssetLocks)
    func didReceiveUnlockHash(_ hash: String)
    func didReceiveFee(_ fee: BigUInt)
    func didReceiveError(_ error: GovernanceUnlockConfirmInteractorError)
}

protocol GovernanceUnlockConfirmWireframeProtocol: AlertPresentable, CommonRetryable,
                                                    MessageSheetPresentable, AddressOptionsPresentable,
                                                    ExtrinsicSubmissionPresenting, GovernanceErrorPresentable  {}
