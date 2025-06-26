import Foundation
import Operation_iOS

protocol MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(result: Result<[DataProviderChange<Multisig.PendingOperation>], Error>)
}

extension MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(result _: Result<[DataProviderChange<Multisig.PendingOperation>], Error>) {}
}
