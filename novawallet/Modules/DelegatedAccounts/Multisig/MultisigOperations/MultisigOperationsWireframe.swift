import Foundation

final class MultisigOperationsWireframe {}

extension MultisigOperationsWireframe: MultisigOperationsWireframeProtocol {
    func showOperationDetails(
        from view: (any MultisigOperationsViewProtocol)?,
        operation: Multisig.PendingOperationProxyModel,
        flowState: MultisigOperationsFlowState
    ) {
        guard let confirmView = MultisigOperationConfirmViewFactory.createView(
            for: operation,
            flowState: flowState
        ) else {
            return
        }

        let operationNavigationController = NovaNavigationController(rootViewController: confirmView.controller)

        view?.controller.presentWithCardLayout(operationNavigationController, animated: true)
    }
}
