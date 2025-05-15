import Foundation

extension MetaAccountModel {
    func isProxied(accountId: AccountId, chainId: ChainModel.Id) -> Bool {
        type == .proxied && has(accountId: accountId, chainId: chainId)
    }

    func isSignatory(for multisig: MultisigAccountType) -> Bool {
        switch multisig {
        case let .universal(multisig):
            multisig.signatory == substrateAccountId || multisig.signatory == ethereumAddress
        case let .singleChain(chainAccount):
            chainAccounts.contains {
                $0.chainId == chainAccount.chainId && $0.accountId == chainAccount.multisig?.signatory
            }
        }
    }

    func isDelegated() -> Bool {
        type == .proxied || type == .multisig
    }

    func proxyChainAccount(
        chainId: ChainModel.Id
    ) -> ChainAccountModel? {
        chainAccounts.first { $0.chainId == chainId && $0.proxy != nil }
    }

    func multisigAccount() -> MultisigAccountType? {
        if let multisig {
            .universal(multisig: multisig)
        } else if let chainAccount = chainAccounts.first(where: { $0.multisig != nil }),
                  let multisig = chainAccount.multisig {
            .singleChain(chainAccount: chainAccount)
        } else {
            nil
        }
    }

    func proxy() -> DelegatedAccount.ProxyAccountModel? {
        guard type == .proxied,
              let chainAccount = chainAccounts.first(where: { $0.proxy != nil }) else {
            return nil
        }

        return chainAccount.proxy
    }

    func address(for chainAsset: ChainAsset) throws -> AccountAddress? {
        let request = chainAsset.chain.accountRequest()
        return fetch(for: request)?.toAddress()
    }

    func delegationId() -> MetaAccountDelegationId? {
        switch type {
        case .multisig:
            var multisigModel: DelegatedAccount.MultisigAccountModel?
            var chainId: ChainModel.Id?

            switch multisigAccount() {
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
                let proxyAccountId = proxy()?.accountId,
                let proxiedAccount = chainAccounts.first(where: { $0.proxy?.accountId == proxyAccountId }),
                let proxy = proxiedAccount.proxy
            else { return nil }

            return MetaAccountDelegationId(
                delegateAccountId: proxyAccountId,
                delegatorId: proxiedAccount.accountId,
                chainId: proxiedAccount.chainId,
                delegationType: .proxy(proxy.type)
            )
        default:
            return nil
        }
    }

    func delegatedAccountStatus() -> DelegatedAccount.Status? {
        if let proxyAccount = proxy() {
            proxyAccount.status
        } else if let multisigAccount = multisigAccount()?.multisig {
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
