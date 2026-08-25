import Foundation

protocol SubtensorUnstakeSetupInteractorInputProtocol: SubtensorStakingDelegateInteractorInputProtocol {}

protocol SubtensorUnstakeSetupInteractorOutputProtocol: SubtensorStakingDelegateInteractorOutputProtocol {}

protocol SubtensorUnstakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable,
    CollatorStakingDelegationSelectable,
    SubtensorStakingErrorPresentable {
    func showConfirm(
        from view: CollatorStkPartialUnstakeSetupViewProtocol?,
        model: SubtensorUnstakeConfirmModel
    )
}
