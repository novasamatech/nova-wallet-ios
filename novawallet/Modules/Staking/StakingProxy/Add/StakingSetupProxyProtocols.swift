import Foundation_iOS

protocol StakingSetupProxyViewProtocol: StakingSetupProxyBaseViewProtocol {
    func didReceive(token: String)
    func didReceiveProxyInputState(focused: Bool, empty: Bool?)
    func didReceiveProxyAccountInput(viewModel: InputViewModelProtocol)
    func didReceiveWeb3NameProxy(viewModel: LoadableViewModelState<Web3NameReceipientView.Model>)
    func didReceiveYourWallets(state: YourWalletsControl.State)
    func didReceiveAccountState(viewModel: AccountFieldStateViewModel)
}

protocol StakingSetupProxyPresenterProtocol: StakingSetupProxyBasePresenterProtocol {
    func complete(proxyInput: String)
    func updateProxy(partialAddress: String)
    func showWeb3NameProxy()
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

protocol StakingSetupProxyWireframeProtocol: StakingSetupProxyBaseWireframeProtocol, Web3NameAddressListPresentable,
    AddressOptionsPresentable, YourWalletsPresentable, ScanAddressPresentable {
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
