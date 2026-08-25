import Foundation

protocol SubtensorStakingSetupInteractorInputProtocol: SubtensorStakingDelegateInteractorInputProtocol {}

protocol SubtensorStakingSetupInteractorOutputProtocol: SubtensorStakingDelegateInteractorOutputProtocol {}

protocol SubtensorStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable,
    CollatorStakingDelegationSelectable,
    SubtensorStakingErrorPresentable {
    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        model: SubtensorStakingConfirmModel
    )

    func showDelegateSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: CollatorStakingSelectDelegate
    )
}
