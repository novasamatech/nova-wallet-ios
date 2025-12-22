protocol PVWelcomeViewProtocol: ControllerBackedProtocol {
    func didChangeMode(_ mode: PVWelcomeMode)
}

protocol PVWelcomePresenterProtocol: AnyObject {
    func scanQr()
    func didSelectMode(_ mode: PVWelcomeMode)
}

protocol PVWelcomeWireframeProtocol: AnyObject {
    func showScanQR(
        from view: PVWelcomeViewProtocol?,
        type: ParitySignerType
    )
}
