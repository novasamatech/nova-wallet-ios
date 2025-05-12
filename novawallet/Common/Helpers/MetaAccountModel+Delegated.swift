import Foundation

extension MetaAccountModel {
    func isProxied(accountId: AccountId, chainId: ChainModel.Id) -> Bool {
        type == .proxied && has(accountId: accountId, chainId: chainId)
    }

    func isSignatory(for multisig: MultisigAccountType) -> Bool {
        switch multisig {
        case let .universal(multisig):
            multisig.signatory == substrateAccountId || multisig.signatory == ethereumAddress
        case let .singleChain(chainAccount, multisig):
            chainAccounts.contains {
                $0.chainId == chainAccount.chainId && $0.accountId == multisig.signatory
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
            .singleChain(chainAccount: chainAccount, multisig: multisig)
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
            guard let multisigModel = multisigAccount()?.multisig.multisigAccount else {
                return nil
            }

            return MetaAccountDelegationId(
                delegatedAccountId: multisigModel.accountId,
                delegatorId: multisigModel.signatory
            )
        case .proxied:
            guard
                let proxyAccountId = proxy()?.accountId,
                let proxiedAccount = chainAccounts.first(where: { $0.proxy?.accountId == proxyAccountId })
            else { return nil }

            return MetaAccountDelegationId(
                delegatedAccountId: proxyAccountId,
                delegatorId: proxiedAccount.accountId
            )
        default:
            return nil
        }
    }

    func delegatedAccountStatus() -> DelegatedAccount.Status? {
        if let proxyAccount = proxy() {
            proxyAccount.status
        } else if let multisigAccount = multisigAccount()?.multisig.multisigAccount {
            multisigAccount.status
        } else {
            nil
        }
    }
}

extension MetaAccountModel {
    enum MultisigAccountType {
        case universal(multisig: DelegatedAccount.MultisigAccountModel)
        case singleChain(chainAccount: ChainAccountModel, multisig: DelegatedAccount.MultisigAccountModel)

        var multisig: (chainAccount: ChainAccountModel?, multisigAccount: DelegatedAccount.MultisigAccountModel?) {
            switch self {
            case let .universal(multisig):
                (nil, multisig)
            case let .singleChain(chainAccount, multisig):
                (chainAccount, multisig)
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
