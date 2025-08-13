import Foundation

struct DelegateIdentifier: Hashable {
    let delegatorAccountId: AccountId
    let delegateAccountId: AccountId
    let delegateType: DelegationType
}

enum DelegationType: Hashable {
    case proxy(Proxy.ProxyType)
    case multisig

    var delegationClass: DelegationClass {
        switch self {
        case .proxy:
            return .proxy
        case .multisig:
            return .multisig
        }
    }
}

enum DelegationClass: Equatable {
    case proxy
    case multisig
}
