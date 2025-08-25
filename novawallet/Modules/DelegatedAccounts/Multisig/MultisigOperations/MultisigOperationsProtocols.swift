import Foundation
import Operation_iOS

protocol MultisigOperationsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: MultisigOperationsListViewModel)
}

protocol MultisigOperationsPresenterProtocol: AnyObject {
    func setup()
    func selectOperation(with identifier: String)
}

protocol MultisigOperationsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationsInteractorOutputProtocol: AnyObject {
    func didReceiveOperations(changes: [DataProviderChange<Multisig.PendingOperationProxyModel>])
    func didReceiveChains(changes: [DataProviderChange<ChainModel>])
    func didReceive(error: Error)
}

protocol MultisigOperationsWireframeProtocol: AlertPresentable, ErrorPresentable {
    func showOperationDetails(
        from view: MultisigOperationsViewProtocol?,
        operation: Multisig.PendingOperationProxyModel
    )
}
