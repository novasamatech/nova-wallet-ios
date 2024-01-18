protocol StakingProxyManagementViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModels: [StakingProxyManagementViewModel])
}

protocol StakingProxyManagementPresenterProtocol: AnyObject {
    func setup()
    func addProxy()
    func showOptions(accountId: AccountId)
}

protocol StakingProxyManagementInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingProxyManagementInteractorOutputProtocol: AnyObject {
    func didReceive(identities: [AccountId: AccountIdentity])
    func didReceive(proxyDefinition: ProxyDefinition?)
    func didReceive(error: StakingProxyManagementError)
}

protocol StakingProxyManagementWireframeProtocol: AnyObject, AddressOptionsPresentable {
    func showAddProxy(from view: ControllerBackedProtocol?)
    func showRevokeProxyAccess(from view: ControllerBackedProtocol?)
}

enum StakingProxyManagementError: Error {
    case identities(Error)
    case proxyDefifnition(Error)
}

struct StakingProxyManagementViewModel: Hashable {
    let info: WalletView.ViewModel
    let accountId: AccountId
}
