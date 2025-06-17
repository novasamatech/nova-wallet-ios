import Foundation
import Operation_iOS

protocol ProxyListLocalSubscriptionHandler {
    func handleAllProxies(result: Result<[DataProviderChange<DelegatedAccount.ProxyAccountModel>], Error>)
    func handleProxies(
        result: Result<ProxyDefinition?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )
}

extension ProxyListLocalSubscriptionHandler {
    func handleAllProxies(result _: Result<[DataProviderChange<DelegatedAccount.ProxyAccountModel>], Error>) {}
    func handleProxies(
        result _: Result<ProxyDefinition?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}
}
