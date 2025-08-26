protocol NotificationWalletListViewProtocol: WalletsListViewProtocol {
    func setAction(enabled: Bool)
    func setTitle(_ title: String)
}

protocol NotificationWalletListPresenterProtocol: WalletsListPresenterProtocol {
    func selectItem(at index: Int, section: Int)
    func confirm()
}

protocol NotificationWalletListInteractorInputProtocol: WalletsListInteractorInputProtocol {}

protocol NotificationWalletListInteractorOutputProtocol: WalletsListInteractorOutputProtocol {}

protocol NotificationWalletListWireframeProtocol: WalletsListWireframeProtocol {
    func complete(from view: ControllerBackedProtocol?, selectedWallets: [Web3Alert.LocalWallet])
}
