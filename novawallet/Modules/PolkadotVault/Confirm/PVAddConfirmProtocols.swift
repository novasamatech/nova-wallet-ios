protocol PVAddConfirmInteractorInputProtocol: AnyObject {
    func save(with walletName: String)
}

protocol PVAddConfirmInteractorOutputProtocol: AnyObject {
    func didCreateWallet()
    func didReceive(error: Error)
}

protocol PVAddConfirmWireframeProtocol: AlertPresentable, ErrorPresentable {
    func complete(on view: ControllerBackedProtocol?)
}
