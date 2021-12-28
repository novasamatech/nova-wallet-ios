protocol DAppAuthConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: DAppAuthViewModel)
}

protocol DAppAuthConfirmPresenterProtocol: AnyObject {
    func setup()
    func allow()
    func deny()
}

protocol DAppAuthConfirmWireframeProtocol: AnyObject {
    func close(from view: DAppAuthConfirmViewProtocol?)
}

protocol DAppAuthDelegate: AnyObject {
    func didReceiveAuthResponse(_ response: DAppAuthResponse, for request: DAppAuthRequest)
}
