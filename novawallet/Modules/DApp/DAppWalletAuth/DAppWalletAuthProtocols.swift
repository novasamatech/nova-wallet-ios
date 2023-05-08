protocol DAppWalletAuthViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppWalletAuthViewModel)
}

protocol DAppWalletAuthPresenterProtocol: AnyObject {
    func setup()
    func approve()
    func reject()
}

protocol DAppWalletAuthInteractorInputProtocol: AnyObject {
    func fetchTotalValue(for wallet: MetaAccountModel)
}

protocol DAppWalletAuthInteractorOutputProtocol: AnyObject {
    func didFetchTotalValue(_ value: Decimal, wallet: MetaAccountModel)
}

protocol DAppWalletAuthWireframeProtocol: AnyObject {
    func close(from view: DAppWalletAuthViewProtocol?)
}
