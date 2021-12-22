protocol DAppOperationConfirmViewProtocol: ControllerBackedProtocol {}

protocol DAppOperationConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol DAppOperationConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func confirm()
    func reject()
}

protocol DAppOperationConfirmInteractorOutputProtocol: AnyObject {
    func didReceive(modelResult: Result<DAppOperationConfirmModel, Error>)
    func didReceive(feeResult: Result<RuntimeDispatchInfo, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(responseResult: Result<DAppOperationResponse, Error>)
}

protocol DAppOperationConfirmWireframeProtocol: AnyObject {}

protocol DAppOperationConfirmDelegate: AnyObject {
    func didReceiveConfirmationResponse(_ response: DAppOperationResponse, for request: DAppOperationRequest)
}
