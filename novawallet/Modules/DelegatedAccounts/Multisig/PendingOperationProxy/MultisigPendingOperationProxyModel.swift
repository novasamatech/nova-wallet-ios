import Foundation
import Operation_iOS

extension Multisig {
    struct PendingOperationProxyModel {
        let operation: PendingOperation
        let formattedModel: FormattedCall?

        var timestamp: UInt64 {
            operation.timestamp
        }
    }
}

extension Multisig.PendingOperationProxyModel: Identifiable {
    var identifier: String {
        operation.identifier
    }
}
