import SubstrateSdk

protocol DAppOperationConfirmViewProtocol: ControllerBackedProtocol {
    func didReceive(confirmationViewModel: DAppOperationConfirmViewModel)
    func didReceive(feeViewModel: DAppOperationFeeViewModel)
}

protocol DAppOperationConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func reject()
    func activateTxDetails()
    func showAccountOptions()
}

protocol DAppOperationConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func confirm()
    func reject()
    func prepareTxDetails()
}

protocol DAppOperationConfirmInteractorOutputProtocol: AnyObject {
    func didReceive(modelResult: Result<DAppOperationConfirmModel, Error>)
    func didReceive(feeResult: Result<RuntimeDispatchInfo, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(responseResult: Result<DAppOperationResponse, Error>, for request: DAppOperationRequest)
    func didReceive(txDetailsResult: Result<JSON, Error>)
}

protocol DAppOperationConfirmWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    MessageSheetPresentable, AddressOptionsPresentable {
    func close(view: DAppOperationConfirmViewProtocol?)
    func showTxDetails(from view: DAppOperationConfirmViewProtocol?, json: JSON)
}

protocol DAppOperationConfirmDelegate: AnyObject {
    func didReceiveConfirmationResponse(_ response: DAppOperationResponse, for request: DAppOperationRequest)
}
