import Foundation

extension Proxy {
    struct Account: Hashable {
        let accountId: AccountId
        let type: Proxy.ProxyType
        let delay: BlockNumber

        var hasDelay: Bool {
            delay > 0
        }
    }
}
