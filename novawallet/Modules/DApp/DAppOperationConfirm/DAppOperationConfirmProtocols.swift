protocol DAppOperationConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(confimationViewModel: DAppOperationConfirmViewModel)
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
}

protocol DAppOperationConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func reject()
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
    func didReceive(responseResult: Result<DAppOperationResponse, Error>, for request: DAppOperationRequest)
}

protocol DAppOperationConfirmWireframeProtocol: AlertPresentable, ErrorPresentable {
    func close(view: DAppOperationConfirmViewProtocol?)
}

protocol DAppOperationConfirmDelegate: AnyObject {
    func didReceiveConfirmationResponse(_ response: DAppOperationResponse, for request: DAppOperationRequest)
}
