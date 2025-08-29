import Foundation

struct DelegateIdentifier: Hashable {
    let delegatorAccountId: AccountId
    let delegateAccountId: AccountId
    let delegateType: DelegationType

    var chainId: ChainModel.Id? {
        switch delegateType {
        case let .proxy(model):
            model.chainId
        case let .multisig(model):
            model.chainId
        }
    }

    func existsInChainWithId(_ identifier: ChainModel.Id) -> Bool {
        chainId == nil || chainId == identifier
    }
}

enum DelegationType: Hashable, Equatable {
    enum MultisigModel: Hashable, Equatable {
        case uniSubstrate
        case uniEvm
        case singleChain(ChainModel.Id)

        var chainId: ChainModel.Id? {
            switch self {
            case .uniSubstrate, .uniEvm:
                return nil
            case let .singleChain(chainId):
                return chainId
            }
        }
    }

    struct ProxyModel: Hashable, Equatable {
        let type: Proxy.ProxyType
        let chainId: ChainModel.Id
    }

    case proxy(ProxyModel)
    case multisig(MultisigModel)

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
