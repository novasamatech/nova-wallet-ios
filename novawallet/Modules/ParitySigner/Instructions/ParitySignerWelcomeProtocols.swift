protocol ParitySignerWelcomeViewProtocol: ControllerBackedProtocol {
    func didChangeMode(_ mode: ParitySignerWelcomeMode)
}

protocol ParitySignerWelcomePresenterProtocol: AnyObject {
    func scanQr()
    func didSelectMode(_ mode: ParitySignerWelcomeMode)
}

protocol ParitySignerWelcomeWireframeProtocol: AnyObject {
    func showScanQR(from view: ParitySignerWelcomeViewProtocol?, type: ParitySignerType, mode: ParitySignerWelcomeMode)
}
