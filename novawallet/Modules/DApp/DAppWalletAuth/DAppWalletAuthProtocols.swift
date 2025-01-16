import Foundation_iOS

protocol DAppWalletAuthViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppWalletAuthViewModel)
}

protocol DAppWalletAuthPresenterProtocol: AnyObject {
    func setup()
    func approve()
    func reject()
    func selectWallet()
    func showNetworks()
}

protocol DAppWalletAuthInteractorInputProtocol: AnyObject {
    func setup()
    func apply(wallet: MetaAccountModel)
}

protocol DAppWalletAuthInteractorOutputProtocol: AnyObject {
    func didFetchTotalValue(_ value: Decimal, wallet: MetaAccountModel)
    func didReceive(error: BalancesStoreError)
}

protocol DAppWalletAuthWireframeProtocol: WalletChoosePresentable {
    func close(from view: DAppWalletAuthViewProtocol?)
    func showNetworksResolution(
        from view: DAppWalletAuthViewProtocol?,
        requiredResolution: DAppChainsResolution,
        optionalResolution: DAppChainsResolution?
    )
}
