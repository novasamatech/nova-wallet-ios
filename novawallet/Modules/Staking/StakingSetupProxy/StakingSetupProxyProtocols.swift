protocol StakingSetupProxyViewProtocol: ControllerBackedProtocol {
    func didReceiveProxyDeposit(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceive(token: String)
}

protocol StakingSetupProxyPresenterProtocol: AnyObject {
    func setup()
    func complete(authority: String)
    func showDepositInfo()
}

protocol StakingSetupProxyInteractorInputProtocol: StakingProxyBaseInteractorInputProtocol {}

protocol StakingSetupProxyInteractorOutputProtocol: StakingProxyBaseInteractorOutputProtocol {}

protocol StakingSetupProxyWireframeProtocol: AnyObject {}
