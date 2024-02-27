protocol NotificationWalletListViewProtocol: WalletsListViewProtocol {}

protocol NotificationWalletListPresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
    func confirm()
}

protocol NotificationWalletListInteractorInputProtocol: WalletsListInteractorInputProtocol {}

protocol NotificationWalletListInteractorOutputProtocol: WalletsListInteractorOutputProtocol {}

protocol NotificationWalletListWireframeProtocol: WalletsListWireframeProtocol {
    func complete(selectedWallets: [Web3AlertWallet])
}
