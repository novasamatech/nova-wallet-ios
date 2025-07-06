import Foundation

final class MultisigOperationConfirmWireframe: MultisigOperationConfirmWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showAddCallData(
        from view: (any ControllerBackedProtocol)?,
        for operation: Multisig.PendingOperation
    ) {
        let callDataView = MultisigCallDataImportViewFactory.createView(
            pendingOperation: operation
        )

        view?.controller.navigationController?.pushViewController(
            callDataView.controller,
            animated: true
        )
    }
}
