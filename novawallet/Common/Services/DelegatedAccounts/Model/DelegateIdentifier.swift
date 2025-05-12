import Foundation

struct DelegateIdentifier: Hashable {
    let delegatorAccountId: AccountId
    let delegateAccountId: AccountId
    let delegateType: DelegateType
}

enum DelegateType: Hashable {
    case proxy(Proxy.ProxyType)
    case multisig
}
