protocol YourWalletsViewProtocol: AnyObject {}

protocol YourWalletsPresenterProtocol: AnyObject {
    func setup()
}

protocol YourWalletsInteractorInputProtocol: AnyObject {}

protocol YourWalletsInteractorOutputProtocol: AnyObject {}

protocol YourWalletsWireframeProtocol: AnyObject {}

protocol YourWalletsDelegate: AnyObject {
    func selectWallet(address: AccountAddress?)
}
