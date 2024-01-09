protocol StakingSetupProxyViewProtocol: AnyObject {}

protocol StakingSetupProxyPresenterProtocol: AnyObject {
    func setup()
    func complete(authority: String)
    func showDepositInfo()
}

protocol StakingSetupProxyInteractorInputProtocol: AnyObject {}

protocol StakingSetupProxyInteractorOutputProtocol: AnyObject {}

protocol StakingSetupProxyWireframeProtocol: AnyObject {}
