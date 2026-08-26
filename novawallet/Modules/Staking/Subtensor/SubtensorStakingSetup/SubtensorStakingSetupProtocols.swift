import Foundation

protocol SubtensorStakingSetupViewProtocol: CollatorStakingSetupViewProtocol {
    func didReceiveStakeTarget(viewModel: SubtensorStakeTargetViewModel)
    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?)
    func didReceiveSlippage(viewModel: String?)
    func didReceiveRewardHidden(_ isHidden: Bool)
}

protocol SubtensorStakingSetupPresenterProtocol: CollatorStakingSetupPresenterProtocol {
    func selectStakeTarget()
    func selectSlippage()
}

protocol SubtensorStakingSetupInteractorInputProtocol: SubtensorStakingDelegateInteractorInputProtocol {}

protocol SubtensorStakingSetupInteractorOutputProtocol: SubtensorStakingDelegateInteractorOutputProtocol {
    /// the engine rather than a rate: the picked delegate's take is only known in the presenter
    /// and has to be netted at render time (spec §6.2)
    func didReceiveRewardEngine(_ engine: SubtensorRewardCalculatorEngineProtocol?)
}

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

    func showSubnetRiskNote(
        from view: CollatorStakingSetupViewProtocol?,
        onContinue: @escaping () -> Void
    )

    func showSubnetSelection(
        from view: CollatorStakingSetupViewProtocol?,
        delegate: SubtensorSubnetSelectDelegate,
        delegateTake: UInt16?
    )

    func showSlippageEdit(
        from view: CollatorStakingSetupViewProtocol?,
        current: BigRational,
        completion: @escaping (BigRational) -> Void
    )
}
