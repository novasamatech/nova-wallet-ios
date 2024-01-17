protocol StakingConfirmProxyViewProtocol: StakingSetupProxyBaseViewProtocol {
    func didReceiveNetwork(viewModel: NetworkViewModel)
    func didReceiveWallet(viewModel: StackCellViewModel)
    func didReceiveProxiedAddress(viewModel: DisplayAddressViewModel)
    func didReceiveProxyAddress(viewModel: DisplayAddressViewModel)
    func didStartLoading()
    func didStopLoading()
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
    func didSubmit()
    func didReceive(error: StakingConfirmProxyError)
}

protocol StakingConfirmProxyWireframeProtocol: StakingSetupProxyBaseWireframeProtocol, AddressOptionsPresentable {}

enum StakingConfirmProxyError: Error {
    case submit(Error)
}
