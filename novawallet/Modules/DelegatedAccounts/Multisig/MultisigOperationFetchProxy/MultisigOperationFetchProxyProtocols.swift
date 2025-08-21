import Foundation

protocol MultisigOperationFetchProxyViewProtocol: ControllerBackedProtocol {
    func didReceive(loading: Bool)
}

protocol MultisigOperationFetchProxyPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationFetchProxyInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationFetchProxyInteractorOutputProtocol: AnyObject {
    func didReceiveOperation(_ operation: Multisig.PendingOperationProxyModel?)
    func didReceiveError(_ error: MultisigOperationFetchProxyError)
}

protocol MultisigOperationFetchProxyWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showConfirmationData(
        from view: ControllerBackedProtocol?,
        for operation: Multisig.PendingOperationProxyModel
    )

    func close(from view: ControllerBackedProtocol?)
}
