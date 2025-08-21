import Foundation

final class MultisigOperationFetchProxyWireframe {
    let flowState: MultisigOperationsFlowState?

    init(flowState: MultisigOperationsFlowState?) {
        self.flowState = flowState
    }
}

// MARK: - MultisigOperationFetchProxyWireframeProtocol

extension MultisigOperationFetchProxyWireframe: MultisigOperationFetchProxyWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showConfirmationData(
        from view: ControllerBackedProtocol?,
        for operation: Multisig.PendingOperationProxyModel,
        flowState: MultisigOperationsFlowState
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
