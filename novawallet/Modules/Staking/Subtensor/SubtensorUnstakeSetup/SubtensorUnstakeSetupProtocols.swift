import Foundation

protocol SubtensorUnstakeSetupViewProtocol: CollatorStkPartialUnstakeSetupViewProtocol {
    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?)
    func didReceiveSlippage(viewModel: String?)
    func didReceiveUnstakeUnavailable(_ isUnavailable: Bool)
}

protocol SubtensorUnstakeSetupPresenterProtocol: CollatorStkPartialUnstakeSetupPresenterProtocol {
    func selectSlippage()
}

protocol SubtensorUnstakeSetupInteractorInputProtocol: SubtensorStakingDelegateInteractorInputProtocol {
    func retrySubnetsInfo()
    func refreshPositions()
}

protocol SubtensorUnstakeSetupInteractorOutputProtocol: SubtensorStakingDelegateInteractorOutputProtocol {
    func didReceiveSubnetsInfo(_ info: SubtensorSubnetsInfo)
    func didReceiveSubnetsInfoError(_ error: Error)
    func didReceivePositionsSyncFailed(_ isFailed: Bool)
}

protocol SubtensorUnstakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable,
    CollatorStakingDelegationSelectable,
    SubtensorStakingErrorPresentable {
    func showConfirm(
        from view: CollatorStkPartialUnstakeSetupViewProtocol?,
        model: SubtensorUnstakeConfirmModel
    )

    func showSlippageEdit(
        from view: CollatorStkPartialUnstakeSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    )
}
