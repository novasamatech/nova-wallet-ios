protocol LedgerInstructionsViewProtocol: ControllerBackedProtocol {}

protocol LedgerInstructionsPresenterProtocol: AnyObject {
    func showHint()
    func proceed()
}

protocol LedgerInstructionsWireframeProtocol: WebPresentable {
    func showNetworkSelection(from view: LedgerInstructionsViewProtocol?)
}
