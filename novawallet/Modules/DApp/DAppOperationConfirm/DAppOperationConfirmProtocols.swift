protocol DAppOperationConfirmViewProtocol: ControllerBackedProtocol {}

protocol DAppOperationConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol DAppOperationConfirmInteractorInputProtocol: AnyObject {}

protocol DAppOperationConfirmInteractorOutputProtocol: AnyObject {}

protocol DAppOperationConfirmWireframeProtocol: AnyObject {}

protocol DAppOperationConfirmDelegate: AnyObject {
    func didReceiveConfirmationResponse(_ response: DAppOperationResponse, for request: DAppOperationRequest)
}
