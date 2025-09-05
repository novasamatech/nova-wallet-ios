import Foundation

protocol DiscoveredDelegatedAccountProtocol {
    var accountId: AccountId { get }
    var delegateAccountId: AccountId { get }
    var usability: DiscoveredAccount.Usability { get }
}

enum DiscoveredAccount {
    enum Usability {
        case concreteChain(ChainModel.Id)
        case universal

        func supports(chainId: ChainModel.Id) -> Bool {
            switch self {
            case let .concreteChain(concreteChainId):
                chainId == concreteChainId
            case .universal:
                true
            }
        }
    }

    struct ProxiedModel: Hashable {
        let proxyAccountId: AccountId
        let proxiedAccountId: AccountId
        let type: Proxy.ProxyType
        let chainId: ChainModel.Id
    }

    struct MultisigModel: Hashable {
        let accountId: AccountId
        let signatory: AccountId
        let signatories: [AccountId]
        let threshold: Int

        func otherSignatories(than signatory: AccountId) -> [AccountId] {
            signatories.filter { $0 != signatory }
        }
    }
}

extension DiscoveredAccount.ProxiedModel: DiscoveredDelegatedAccountProtocol {
    var accountId: AccountId {
        proxiedAccountId
    }

    var delegateAccountId: AccountId {
        proxyAccountId
    }

    var usability: DiscoveredAccount.Usability {
        .concreteChain(chainId)
    }
}

extension DiscoveredAccount.MultisigModel: DiscoveredDelegatedAccountProtocol {
    var delegateAccountId: AccountId {
        signatory
    }

    var usability: DiscoveredAccount.Usability {
        .universal
    }
}
