import Foundation

final class MultisigOperationsWireframe {
    private let flowState: MultisigOperationsFlowState

    init(flowState: MultisigOperationsFlowState) {
        self.flowState = flowState
    }
}

extension MultisigOperationsWireframe: MultisigOperationsWireframeProtocol {
    func showOperationDetails(
        from view: (any MultisigOperationsViewProtocol)?,
        operation: Multisig.PendingOperationProxyModel
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
