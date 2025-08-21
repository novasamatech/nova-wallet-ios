import Foundation

final class MultisigOperationsWireframe {}

extension MultisigOperationsWireframe: MultisigOperationsWireframeProtocol {
    func showOperationDetails(
        from view: (any MultisigOperationsViewProtocol)?,
        operation: Multisig.PendingOperationProxyModel,
        flowState: MultisigOperationsFlowState
    ) {
        guard let multisigOperationView = MultisigOperationConfirmViewFactory.createView(
            for: operation,
            flowState: flowState
        ) else {
            return
        }

        let operationNavigationController = NovaNavigationController(
            rootViewController: multisigOperationView.controller
        )

        view?.controller.presentWithCardLayout(operationNavigationController, animated: true)
    }
}
