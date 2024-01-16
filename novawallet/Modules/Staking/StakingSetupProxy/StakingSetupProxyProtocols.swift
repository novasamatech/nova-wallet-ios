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
    func proceed()
    func scanAddressCode()
}

protocol StakingSetupProxyInteractorInputProtocol: StakingProxyBaseInteractorInputProtocol {
    func search(web3Name: String)
    func refetchAccounts()
}

protocol StakingSetupProxyInteractorOutputProtocol: StakingProxyBaseInteractorOutputProtocol {
    func didReceive(error: StakingSetupProxyError)
    func didReceive(recipients: [Web3TransferRecipient], for name: String)
    func didReceive(yourWallets: [MetaAccountChainResponse])
}

protocol StakingSetupProxyWireframeProtocol: StakingSetupProxyBaseWireframeProtocol, ProxyErrorPresentable, AlertPresentable,
    CommonRetryable, ErrorPresentable, Web3NameAddressListPresentable, AddressOptionsPresentable,
    YourWalletsPresentable, ScanAddressPresentable {
    func checkDismissing(view: ControllerBackedProtocol?) -> Bool
    func showConfirmation(
        from: ControllerBackedProtocol?,
        proxyAddress: AccountAddress
    )
}

enum StakingSetupProxyError: Error {
    case web3Name(Web3NameServiceError)
    case fetchMetaAccounts(Error)
}
