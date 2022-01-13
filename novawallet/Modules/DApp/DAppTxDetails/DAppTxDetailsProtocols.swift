protocol DAppTxDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(txDetails: String)
}

protocol DAppTxDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol DAppTxDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DAppTxDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(displayResult: Result<String, Error>)
}

protocol DAppTxDetailsWireframeProtocol: AlertPresentable, ErrorPresentable {}
