import SoraFoundation

protocol StakingSetupProxyViewProtocol: StakingSetupProxyBaseViewProtocol {
    func didReceive(token: String)
    func didReceiveAuthorityInputState(focused: Bool, empty: Bool?)
    func didReceiveAccountInput(viewModel: InputViewModelProtocol)
    func didReceiveWeb3NameAuthority(viewModel: LoadableViewModelState<Web3NameReceipientView.Model>)
    func didReceiveYourWallets(state: YourWalletsControl.State)
}

protocol StakingSetupProxyPresenterProtocol: StakingSetupProxyBasePresenterProtocol {
    func complete(authority: String)
    func updateAuthority(partialAddress: String)
    func showWeb3NameAuthority()
    func didTapOnYourWallets()
}

protocol StakingSetupProxyInteractorInputProtocol: StakingProxyBaseInteractorInputProtocol {
    func search(web3Name: String)
}

protocol StakingSetupProxyInteractorOutputProtocol: StakingProxyBaseInteractorOutputProtocol {
    func didReceive(error: StakingSetupProxyError)
    func didReceive(recipients: [Web3TransferRecipient], for name: String)
    func didReceive(metaChainAccountResponses: [MetaAccountChainResponse])
}

protocol StakingSetupProxyWireframeProtocol: StakingSetupProxyBaseWireframeProtocol,
    ProxyErrorPresentable, AlertPresentable, CommonRetryable, ErrorPresentable,
    Web3NameAddressListPresentable, AddressOptionsPresentable, YourWalletsPresentable {
    func checkDismissing(view: ControllerBackedProtocol?) -> Bool
}

enum StakingSetupProxyError: Error {
    case web3NamesService(Error)
    case web3NameInvalidAddress(chainName: String)
    case fetchMetaAccounts(Error)
}
