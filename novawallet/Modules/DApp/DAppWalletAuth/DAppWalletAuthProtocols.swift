import SoraFoundation

protocol DAppWalletAuthViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppWalletAuthViewModel)
}

protocol DAppWalletAuthPresenterProtocol: AnyObject {
    func setup()
    func approve()
    func reject()
}

protocol DAppWalletAuthInteractorInputProtocol: AnyObject {
    func setup()
    func apply(wallet: MetaAccountModel)
}

protocol DAppWalletAuthInteractorOutputProtocol: AnyObject {
    func didFetchTotalValue(_ value: Decimal, wallet: MetaAccountModel)
    func didReceive(error: BalancesStoreError)
}

protocol DAppWalletAuthWireframeProtocol: AnyObject {
    func close(from view: DAppWalletAuthViewProtocol?)
}
