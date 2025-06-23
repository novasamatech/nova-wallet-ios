import Foundation
import Operation_iOS

protocol MultisigListLocalSubscriptionHandler {
    func handleAllMultisigs(result: Result<[DataProviderChange<DelegatedAccount.MultisigAccountModel>], Error>)
    func handleMultisigPendingOperations(result: Result<[DataProviderChange<Multisig.PendingOperation>], Error>)
}

extension MultisigListLocalSubscriptionHandler {
    func handleAllMultisigs(result _: Result<[DataProviderChange<DelegatedAccount.MultisigAccountModel>], Error>) {}
    func handleMultisigPendingOperations(result _: Result<[DataProviderChange<Multisig.PendingOperation>], Error>) {}
}
