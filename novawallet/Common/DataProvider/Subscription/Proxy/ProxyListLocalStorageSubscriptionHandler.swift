import Foundation
import RobinHood

protocol ProxyListLocalSubscriptionHandler {
    func handleAllProxies(result: Result<[DataProviderChange<ProxyAccountModel>], Error>)
}

extension ProxyListLocalSubscriptionHandler {
    func handleAllProxies(result _: Result<[DataProviderChange<ProxyAccountModel>], Error>) {}
}
