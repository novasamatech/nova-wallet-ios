import Foundation

final class MultisigOperationsWireframe {}

extension MultisigOperationsWireframe: MultisigOperationsWireframeProtocol {
    func showOperationDetails(
        from view: (any MultisigOperationsViewProtocol)?,
        operation: Multisig.PendingOperation
    ) {
        guard let confirmView = MultisigOperationConfirmViewFactory.createView(for: operation) else {
            return
        }

        let operationNavigationController = NovaNavigationController(rootViewController: confirmView.controller)

        view?.controller.presentWithCardLayout(operationNavigationController, animated: true)
    }
}
