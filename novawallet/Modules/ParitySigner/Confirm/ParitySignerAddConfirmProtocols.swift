protocol ParitySignerAddConfirmInteractorInputProtocol: AnyObject {
    func save(with walletName: String)
}

protocol ParitySignerAddConfirmInteractorOutputProtocol: AnyObject {
    func didCreateWallet()
    func didReceive(error: Error)
}

protocol ParitySignerAddConfirmWireframeProtocol: AlertPresentable, ErrorPresentable {
    func complete(on view: ControllerBackedProtocol?)
}
