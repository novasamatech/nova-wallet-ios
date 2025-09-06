import Foundation

final class ProxyMetaAccountFactory {
    let chainModel: ChainModel
    let logger: LoggerProtocol

    init(chainModel: ChainModel, logger: LoggerProtocol) {
        self.chainModel = chainModel
        self.logger = logger
    }
}

private extension ProxyMetaAccountFactory {
    func ensureCanHandle(
        delegatedAccount: DiscoveredDelegatedAccountProtocol
    ) -> DiscoveredAccount.ProxiedModel? {
        guard
            let proxied = delegatedAccount as? DiscoveredAccount.ProxiedModel,
            proxied.chainId == chainModel.chainId else {
            return nil
        }

        return proxied
    }

    func ensureProxyWalletExists(
        for proxied: DiscoveredAccount.ProxiedModel,
        context: DelegatedMetaAccountFactoryContext
    ) -> Bool {
        context.metaAccounts.contains { metaAccount in
            metaAccount.info.has(
                accountId: proxied.proxyAccountId,
                chainId: chainModel.chainId
            )
        }
    }

    func createWallet(
        for proxied: DiscoveredAccount.ProxiedModel,
        context: DelegatedMetaAccountFactoryContext
    ) -> ManagedMetaAccountModel {
        let cryptoType: MultiassetCryptoType = chainModel.isEthereumBased ? .ethereumEcdsa : .sr25519

        let proxy = DelegatedAccount.ProxyAccountModel(
            type: proxied.type,
            accountId: proxied.proxyAccountId,
            status: .new
        )

        let chainAccountModel = ChainAccountModel(
            chainId: chainModel.chainId,
            accountId: proxied.accountId,
            publicKey: proxied.accountId,
            cryptoType: cryptoType.rawValue,
            proxy: proxy,
            multisig: nil
        )

        let name = context.deriveName(for: proxied.accountId, maybeChain: chainModel)

        let newWallet = ManagedMetaAccountModel(info: MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: nil,
            substrateCryptoType: nil,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [chainAccountModel],
            type: .proxied,
            multisig: nil
        ))

        return newWallet
    }
}

extension ProxyMetaAccountFactory: DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        context: DelegatedMetaAccountFactoryContext
    ) -> ManagedMetaAccountModel? {
        guard let proxied = ensureCanHandle(delegatedAccount: delegatedAccount) else {
            return nil
        }

        guard ensureProxyWalletExists(for: proxied, context: context) else {
            return nil
        }

        return createWallet(for: proxied, context: context)
    }
}
