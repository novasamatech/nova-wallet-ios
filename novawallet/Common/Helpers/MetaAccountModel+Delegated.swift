import Foundation

extension MetaAccountModel {
    var multisigAccount: MultisigAccountType? {
        if let multisig {
            .universal(multisig: multisig)
        } else if let chainAccount = chainAccounts.first(where: { $0.multisig != nil }),
                  chainAccount.multisig != nil {
            .singleChain(chainAccount: chainAccount)
        } else {
            nil
        }
    }

    var proxy: DelegatedAccount.ProxyAccountModel? {
        guard type == .proxied,
              let chainAccount = chainAccounts.first(where: { $0.proxy != nil }) else {
            return nil
        }

        return chainAccount.proxy
    }

    var delegationId: MetaAccountDelegationId? {
        switch type {
        case .multisig:
            var multisigModel: DelegatedAccount.MultisigAccountModel?
            var chainId: ChainModel.Id?

            switch multisigAccount {
            case let .universal(multisig):
                multisigModel = multisig
            case let .singleChain(chainAccount):
                multisigModel = chainAccount.multisig
                chainId = chainAccount.chainId
            default:
                return nil
            }

            guard let multisigModel else { return nil }

            return MetaAccountDelegationId(
                delegateAccountId: multisigModel.signatory,
                delegatorId: multisigModel.accountId,
                chainId: chainId,
                delegationType: .multisig
            )
        case .proxied:
            guard
                let proxy,
                let proxiedAccount = chainAccounts.first(where: { $0.proxy?.accountId == proxy.accountId })
            else { return nil }

            return MetaAccountDelegationId(
                delegateAccountId: proxy.accountId,
                delegatorId: proxiedAccount.accountId,
                chainId: proxiedAccount.chainId,
                delegationType: .proxy(proxy.type)
            )
        default:
            return nil
        }
    }

    func isProxied(accountId: AccountId, chainId: ChainModel.Id) -> Bool {
        type == .proxied && has(accountId: accountId, chainId: chainId)
    }

    func isSignatory(for multisig: MultisigAccountType) -> Bool {
        switch multisig {
        case let .universal(multisig):
            return multisig.signatory == substrateAccountId || multisig.signatory == ethereumAddress
        case let .singleChain(chainAccount):
            guard let multisig = chainAccount.multisig else { return false }

            return has(accountId: multisig.signatory, chainId: chainAccount.chainId)
        }
    }

    func isDelegated() -> Bool {
        type.isDelegated
    }

    func proxyChainAccount(
        chainId: ChainModel.Id
    ) -> ChainAccountModel? {
        chainAccounts.first { $0.chainId == chainId && $0.proxy != nil }
    }

    func address(for chain: ChainModel) throws -> AccountAddress? {
        let request = chain.accountRequest()
        return fetch(for: request)?.toAddress()
    }

    func delegatedAccountStatus() -> DelegatedAccount.Status? {
        if let proxyAccount = proxy {
            proxyAccount.status
        } else if let multisigAccount = multisigAccount?.multisig {
            multisigAccount.status
        } else {
            nil
        }
    }
}

extension MetaAccountModel {
    enum MultisigAccountType {
        case universal(multisig: DelegatedAccount.MultisigAccountModel)
        case singleChain(chainAccount: ChainAccountModel)

        // TODO: Should depend on chain otherwise there might be misuse across multiple chains
        var multisig: DelegatedAccount.MultisigAccountModel? {
            switch self {
            case let .universal(multisig):
                multisig
            case let .singleChain(chainAccount):
                chainAccount.multisig
            }
        }

        var isUniversal: Bool {
            if case .universal = self {
                true
            } else {
                false
            }
        }
    }
}
