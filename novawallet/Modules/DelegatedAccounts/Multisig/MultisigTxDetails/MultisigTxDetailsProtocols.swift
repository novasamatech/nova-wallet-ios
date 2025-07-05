protocol MultisigTxDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(txDetails: String)
}

protocol MultisigTxDetailsPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigTxDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigTxDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(displayResult: Result<String, Error>)
}

protocol MultisigTxDetailsWireframeProtocol: AlertPresentable, ErrorPresentable {}
