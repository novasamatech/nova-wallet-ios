protocol MultisigOperationConfirmViewProtocol: ControllerBackedProtocol {}

protocol MultisigOperationConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationConfirmInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveOperation(_ operation: Multisig.PendingOperation?)
}

protocol MultisigOperationConfirmWireframeProtocol: AnyObject {}
