protocol StakingConfirmProxyViewProtocol: StakingSetupProxyBaseViewProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveProxiedAddress(viewModel: DisplayAddressViewModel)
    func didReceiveProxyAddress(viewModel: DisplayAddressViewModel)
    func didReceiveProxyType(viewModel: String)
    func didStartLoading()
    func didStopLoading()
    func didReceiveProxyAddress(title: String)
    func didReceiveProxyType(title: String)
}

protocol StakingConfirmProxyPresenterProtocol: StakingSetupProxyBasePresenterProtocol {
    func showProxiedAddressOptions()
    func showProxyAddressOptions()
    func confirm()
}

protocol StakingConfirmProxyInteractorInputProtocol: StakingProxyBaseInteractorInputProtocol {
    func submit()
}

protocol StakingConfirmProxyInteractorOutputProtocol: StakingProxyBaseInteractorOutputProtocol {
    func didSubmit(model: ExtrinsicSubmittedModel)
    func didReceive(error: StakingConfirmProxyError)
}

protocol StakingConfirmProxyWireframeProtocol: StakingSetupProxyBaseWireframeProtocol,
    AddressOptionsPresentable, ExtrinsicSubmissionPresenting, ModalAlertPresenting,
    ExtrinsicSigningErrorHandling, MessageSheetPresentable, ErrorPresentable {}

enum StakingConfirmProxyError: Error {
    case submit(Error)
}
