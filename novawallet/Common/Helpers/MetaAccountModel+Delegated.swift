import Foundation

extension MetaAccountModel {
    var multisigAccount: MultisigAccountType? {
        if let multisig {
            if substrateAccountId != nil {
                .universalSubstrate(multisig)
            } else {
                .universalEvm(multisig)
            }
        } else if let chainAccount = chainAccounts.first(where: { $0.multisig != nil }),
                  chainAccount.multisig != nil {
            .singleChain(chainAccount)
        } else {
            nil
        }
    }

    func getMultisig(for chain: ChainModel) -> DelegatedAccount.MultisigAccountModel? {
        guard let multisig else {
            return chainAccounts.first {
                $0.multisig != nil && $0.chainId == chain.chainId
            }?.multisig
        }

        if !chain.isEthereumBased, substrateAccountId != nil {
            return multisig
        } else if chain.isEthereumBased, ethereumAddress != nil {
            return multisig
        } else {
            return nil
        }
    }

    var proxy: DelegatedAccount.ProxyAccountModel? {
        guard type == .proxied,
              let chainAccount = chainAccounts.first(where: { $0.proxy != nil }) else {
            return nil
        }

        return chainAccount.proxy
    }

    func isProxied(accountId: AccountId, chainId: ChainModel.Id) -> Bool {
        type == .proxied && has(accountId: accountId, chainId: chainId)
    }

    func isSignatory(for multisig: MultisigAccountType) -> Bool {
        switch multisig {
        case let .universalSubstrate(multisig), let .universalEvm(multisig):
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

    func proxyChainAccount() -> ChainAccountModel? {
        chainAccounts.first { $0.proxy != nil }
    }

    func address(for chain: ChainModel) throws -> AccountAddress? {
        let request = chain.accountRequest()
        return fetch(for: request)?.toAddress()
    }

    func delegatedAccountStatus() -> DelegatedAccount.Status? {
        if let proxyAccount = proxy {
            proxyAccount.status
        } else if let multisigAccount = multisigAccount?.anyChainMultisig {
            multisigAccount.status
        } else {
            nil
        }
    }
}

extension MetaAccountModel {
    enum MultisigAccountType {
        case singleChain(ChainAccountModel)
        case universalSubstrate(DelegatedAccount.MultisigAccountModel)
        case universalEvm(DelegatedAccount.MultisigAccountModel)

        var anyChainMultisig: DelegatedAccount.MultisigAccountModel? {
            switch self {
            case let .universalEvm(multisig), let .universalSubstrate(multisig):
                multisig
            case let .singleChain(chainAccount):
                chainAccount.multisig
            }
        }

        var isUniversal: Bool {
            if case .universalEvm = self {
                true
            } else if case .universalSubstrate = self {
                true
            } else {
                false
            }
        }
    }
}
