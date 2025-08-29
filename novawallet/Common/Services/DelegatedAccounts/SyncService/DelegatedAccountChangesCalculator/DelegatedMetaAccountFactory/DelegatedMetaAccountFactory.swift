import Foundation

struct DelegatedMetaAccountFactoryContext {
    let identities: [AccountId: AccountIdentity]
    let metaAccounts: [ManagedMetaAccountModel]

    func deriveName(for accountId: AccountId, maybeChain: ChainModel?) -> String {
        if let identityName = identities[accountId]?.displayName {
            return identityName
        }

        do {
            if let chain = maybeChain {
                return try accountId.toAddress(using: chain.chainFormat)
            } else {
                return try accountId.toAddressWithDefaultConversion()
            }
        } catch {
            return accountId.toHexWithPrefix()
        }
    }
}

protocol DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        context: DelegatedMetaAccountFactoryContext
    ) -> ManagedMetaAccountModel?
}

final class CompoundDelegatedMetaAccountFactory {
    let factories: [DelegatedMetaAccountFactoryProtocol]

    init(chains: [ChainModel], logger: LoggerProtocol) {
        let hasChainWithMultisigs = chains.contains { $0.hasMultisig }

        var targetFactories: [DelegatedMetaAccountFactoryProtocol] = []

        if hasChainWithMultisigs {
            targetFactories.append(MultisigUniMetaAccountFactory())
        }

        for chain in chains {
            if chain.hasProxy {
                targetFactories.append(
                    ProxyMetaAccountFactory(chainModel: chain, logger: logger)
                )
            }

            if chain.hasMultisig {
                targetFactories.append(
                    MultisigSingleChainAccountFactory(chainModel: chain)
                )
            }
        }

        factories = targetFactories
    }

    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        context: DelegatedMetaAccountFactoryContext
    ) -> [ManagedMetaAccountModel] {
        factories.compactMap { $0.createMetaAccount(for: delegatedAccount, context: context) }
    }
}
