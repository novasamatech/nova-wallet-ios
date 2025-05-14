import Foundation

struct DelegateIdentifier: Hashable {
    let delegatorAccountId: AccountId
    let delegateAccountId: AccountId
    let delegateType: DelegationType
}

enum DelegationType: Hashable {
    case proxy(Proxy.ProxyType)
    case multisig
}
