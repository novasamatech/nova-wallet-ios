import Foundation

protocol MultisigOperationViewProtocol: ControllerBackedProtocol {
    func didReceive(loading: Bool)
}

protocol MultisigOperationPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigOperationInteractorOutputProtocol: AnyObject {
    func didReceiveOperation(_ operation: Multisig.PendingOperationProxyModel?)
}

protocol MultisigOperationWireframeProtocol {
    func showConfirmationData(
        from view: ControllerBackedProtocol?,
        for operation: Multisig.PendingOperationProxyModel
    )
}

enum MultisigOperationModuleInput {
    case operation(Multisig.PendingOperationProxyModel)
    case key(Multisig.PendingOperation.Key)

    var operationKey: Multisig.PendingOperation.Key {
        switch self {
        case let .operation(operation): operation.operation.createKey()
        case let .key(key): key
        }
    }
}
