import Foundation
import Operation_iOS

protocol MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(result: Result<[DataProviderChange<Multisig.PendingOperation>], Error>)

    func handleMultisigPendingOperation(
        result: Result<Multisig.PendingOperation?, Error>,
        identifier: String
    )
}

extension MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(result _: Result<[DataProviderChange<Multisig.PendingOperation>], Error>) {}

    func handleMultisigPendingOperation(
        result _: Result<Multisig.PendingOperation?, Error>,
        identifier _: String
    ) {}
}
