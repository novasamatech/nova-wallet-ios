protocol ParitySignerWelcomeViewProtocol: ControllerBackedProtocol {}

protocol ParitySignerWelcomePresenterProtocol: AnyObject {
    func scanQr()
}

protocol ParitySignerWelcomeInteractorInputProtocol: AnyObject {}

protocol ParitySignerWelcomeInteractorOutputProtocol: AnyObject {}

protocol ParitySignerWelcomeWireframeProtocol: AnyObject {
    func showScanQR(from view: ParitySignerWelcomeViewProtocol?)
}
