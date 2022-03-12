import CommonWallet
protocol OperationDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: OperationDetailsViewModel)
}

protocol OperationDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol OperationDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol OperationDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveDetails(result: Result<OperationDetailsModel, Error>)
}

protocol OperationDetailsWireframeProtocol: AlertPresentable, ErrorPresentable {}
