import Foundation
import Operation_iOS

enum DiscoveredDelegatedAccountUsability {
    case concreteChain(ChainModel.Id)
    case universal
}

protocol DiscoveredDelegatedAccountProtocol {
    var accountId: AccountId { get }
    var delegateAccountId: AccountId { get }
    var usability: DiscoveredDelegatedAccountUsability { get }
}

enum DelegatedAccountsRepository {
    struct ProxiedModel: Hashable {
        let proxyAccountId: AccountId
        let proxiedAccountId: AccountId
        let type: Proxy.ProxyType
        let chainId: ChainModel.Id
    }
    
    struct MultisigModel {
        let accountId: AccountId
        let signatory: AccountId
        let signatories: [AccountId]
        let threshold: Int

        func otherSignatories(than signatory: AccountId) -> [AccountId] {
            signatories.filter { $0 != signatory }
        }
    }

}

extension DelegatedAccountsRepository.ProxiedModel: DiscoveredDelegatedAccountProtocol {
    var accountId: AccountId {
        proxiedAccountId
    }

    var delegateAccountId: AccountId {
        proxyAccountId
    }

    var usability: DiscoveredDelegatedAccountUsability {
        .concreteChain(chainId)
    }
}

extension DelegatedAccountsRepository.MultisigModel: DiscoveredDelegatedAccountProtocol {
    var delegateAccountId: AccountId {
        signatory
    }

    var usability: DiscoveredDelegatedAccountUsability {
        .universal
    }
}

typealias DelegatedAccountsByDelegateMapping = [AccountId: [DiscoveredDelegatedAccountProtocol]]

protocol DelegatedAccountsRepositoryProtocol {
    func fetchDelegatedAccountsWrapper(
        for accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<DelegatedAccountsByDelegateMapping>
}
