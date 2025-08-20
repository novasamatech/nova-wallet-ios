import Foundation

final class MultisigOperationWireframe {
    let flowState: MultisigOperationsFlowState?

    init(flowState: MultisigOperationsFlowState?) {
        self.flowState = flowState
    }
}

// MARK: - MultisigOperationWireframeProtocol

extension MultisigOperationWireframe: MultisigOperationWireframeProtocol {
    func showConfirmationData(
        from view: ControllerBackedProtocol?,
        for operation: Multisig.PendingOperationProxyModel
    ) {
        guard let confirmView = MultisigOperationConfirmViewFactory.createView(
            for: operation,
            flowState: flowState
        ) else {
            return
        }

        view?.controller.navigationController?.setViewControllers(
            [confirmView.controller],
            animated: false
        )
    }
}
