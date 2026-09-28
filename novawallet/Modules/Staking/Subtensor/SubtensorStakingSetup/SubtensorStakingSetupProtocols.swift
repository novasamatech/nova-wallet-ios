import Foundation

protocol SubtensorStakingSetupViewProtocol: CollatorStakingSetupViewProtocol {
    func didReceiveTargetLoading(_ isLoading: Bool)
    func didReceiveStakeTarget(viewModel: SubtensorStakeTargetViewModel)
    func didReceiveQuote(viewModel: SubtensorQuotePanelViewModel?)
    func didReceiveSlippage(viewModel: String?)
    func didReceiveRewardHidden(_ isHidden: Bool)
}

protocol SubtensorStakingSetupPresenterProtocol: CollatorStakingSetupPresenterProtocol {
    func selectStakeTarget()
    func selectSlippage()
}

protocol SubtensorStakingSetupInteractorInputProtocol: SubtensorStakingDelegateInteractorInputProtocol {
    func retryInitialSubnet()
}

protocol SubtensorStakingSetupInteractorOutputProtocol: SubtensorStakingDelegateInteractorOutputProtocol {
    /// the engine rather than a rate: the picked delegate's take is only known in the presenter
    /// and has to be netted at render time (spec §6.2)
    func didReceiveRewardEngine(_ engine: SubtensorRewardCalculatorEngineProtocol?)
    func didReceiveInitialSubnets(_ info: SubtensorSubnetsInfo)
    func didFailInitialSubnets(_ error: Error)
}

protocol SubtensorStakingSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable,
    CollatorStakingDelegationSelectable,
    SubtensorStakingErrorPresentable {
    func showConfirmation(
        from view: CollatorStakingSetupViewProtocol?,
        model: SubtensorStakingConfirmModel
    )

    func showValidatorSelection(
        from view: CollatorStakingSetupViewProtocol?,
        target: SubtensorStakeTarget,
        delegate: SubtensorSubnetSelectDelegate
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
