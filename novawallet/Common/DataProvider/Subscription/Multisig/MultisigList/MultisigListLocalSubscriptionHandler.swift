import Foundation
import Operation_iOS

protocol MultisigListLocalSubscriptionHandler {
    func handleAllMultisigs(result: Result<[DataProviderChange<DelegatedAccount.MultisigAccountModel>], Error>)
}

extension MultisigListLocalSubscriptionHandler {
    func handleAllMultisigs(result _: Result<[DataProviderChange<DelegatedAccount.MultisigAccountModel>], Error>) {}
}
