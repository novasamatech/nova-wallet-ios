import Foundation

final class MultisigOperationsWireframe {}

extension MultisigOperationsWireframe: MultisigOperationsWireframeProtocol {
    func showOperationDetails(
        from _: (any MultisigOperationsViewProtocol)?,
        operation _: Multisig.PendingOperation
    ) {
        // TODO: Implement operation details navigation
    }
}
