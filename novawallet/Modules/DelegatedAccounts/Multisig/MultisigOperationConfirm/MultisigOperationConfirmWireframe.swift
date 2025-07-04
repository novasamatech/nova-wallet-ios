import Foundation

final class MultisigOperationConfirmWireframe: MultisigOperationConfirmWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }

    func showAddCallData(from _: ControllerBackedProtocol?) {
        // TODO: Implement add call data screen
    }
}
