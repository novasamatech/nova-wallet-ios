import Foundation

extension MetaAccountModel {
    func getDelegateIdentifier() -> DelegateIdentifier? {
        switch type {
        case .proxied:
            return getProxyIdentifier()
        case .multisig:
            return getMultisigIdentifier()
        case .secrets, .watchOnly, .genericLedger, .ledger, .paritySigner, .polkadotVault:
            return nil
        }
    }
}

// MARK: Multisig

private extension MetaAccountModel {
    func getMultisigIdentifier() -> DelegateIdentifier? {
        switch multisigAccount {
        case let .universalSubstrate(model):
            return DelegateIdentifier(
                delegatorAccountId: model.accountId,
                delegateAccountId: model.signatory,
                delegateType: .multisig(.uniSubstrate)
            )
        case let .universalEvm(model):
            return DelegateIdentifier(
                delegatorAccountId: model.accountId,
                delegateAccountId: model.signatory,
                delegateType: .multisig(.uniEvm)
            )
        case let .singleChain(model):
            guard let multisig = model.multisig else {
                return nil
            }

            return DelegateIdentifier(
                delegatorAccountId: multisig.accountId,
                delegateAccountId: multisig.signatory,
                delegateType: .multisig(.singleChain(model.chainId))
            )
        case .none:
            return nil
        }
    }
}

// MARK: Proxy

private extension MetaAccountModel {
    func getProxyIdentifier() -> DelegateIdentifier? {
        guard
            let chainAccount = chainAccounts.first(where: { $0.proxy != nil }),
            let proxy = chainAccount.proxy
        else { return nil }

        return DelegateIdentifier(
            delegatorAccountId: chainAccount.accountId,
            delegateAccountId: proxy.accountId,
            delegateType: .proxy(
                .init(
                    type: proxy.type,
                    chainId: chainAccount.chainId
                )
            )
        )
    }
}
