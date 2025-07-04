import Foundation
import Operation_iOS

extension Multisig {
    struct PendingOperationProxyModel {
        let operation: PendingOperation
        let formattedModel: FormattedCall?
    }
}

extension Multisig.PendingOperationProxyModel: Identifiable {
    var identifier: String {
        operation.identifier
    }
}
