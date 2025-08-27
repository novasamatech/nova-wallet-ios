import Foundation

final class ProxyMetaAccountFactory {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }

    private func updateProxyStatus(
        for metaAccount: ManagedMetaAccountModel,
        _ newStatus: DelegatedAccount.Status,
        proxy: DelegatedAccount.ProxyAccountModel
    ) -> ManagedMetaAccountModel {
        let updatedProxy = proxy.replacingStatus(newStatus)

        let newInfo = metaAccount.info.replacingProxy(
            chainId: chainModel.chainId,
            proxy: updatedProxy
        )

        return metaAccount.replacingInfo(newInfo)
    }
}

extension ProxyMetaAccountFactory: DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: any DiscoveredDelegatedAccountProtocol,
        using identities: [AccountId: AccountIdentity],
        metaAccounts _: [ManagedMetaAccountModel]
    ) throws -> ManagedMetaAccountModel {
        guard let proxied = delegatedAccount as? DelegatedAccountsRepository.ProxiedModel else {
            throw DelegatedAccountError.invalidAccountType
        }

        let cryptoType: MultiassetCryptoType = chainModel.isEthereumBased ? .ethereumEcdsa : .sr25519

        let proxy = DelegatedAccount.ProxyAccountModel(
            type: proxied.proxyAccount.type,
            accountId: proxied.proxyAccount.accountId,
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

        let name = try identities[proxied.accountId]?.displayName
            ?? proxied.accountId.toAddress(using: chainModel.chainFormat)

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

    func renew(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel {
        guard
            let proxyAccount = metaAccount.info.proxyChainAccount(chainId: chainModel.chainId),
            let proxy = proxyAccount.proxy,
            proxy.status == .revoked
        else { return metaAccount }

        return updateProxyStatus(
            for: metaAccount,
            .new,
            proxy: proxy
        )
    }

    func markAsRevoked(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel {
        guard
            let proxyAccount = metaAccount.info.proxyChainAccount(chainId: chainModel.chainId),
            let proxy = proxyAccount.proxy
        else { return metaAccount }

        return updateProxyStatus(
            for: metaAccount,
            .revoked,
            proxy: proxy
        )
    }

    func matchesDelegatedAccount(
        _ metaAccount: ManagedMetaAccountModel,
        delegatedAccount: DiscoveredDelegatedAccountProtocol
    ) -> Bool {
        guard
            let remoteProxied = delegatedAccount as? DelegatedAccountsRepository.ProxiedModel,
            let chainAccount = metaAccount.info.proxyChainAccount(chainId: chainModel.chainId),
            let localProxyModel = chainAccount.proxy
        else { return false }

        return chainAccount.accountId == remoteProxied.accountId &&
            localProxyModel.accountId == remoteProxied.proxyAccount.accountId &&
            localProxyModel.type == remoteProxied.proxyAccount.type
    }

    func extractDelegateIdentifier(from metaAccount: ManagedMetaAccountModel) -> DelegateIdentifier? {
        guard
            let chainAccount = metaAccount.info.proxyChainAccount(chainId: chainModel.chainId),
            let proxy = chainAccount.proxy
        else { return nil }

        return DelegateIdentifier(
            delegatorAccountId: chainAccount.accountId,
            delegateAccountId: proxy.accountId,
            delegateType: .proxy(proxy.type)
        )
    }

    func canHandle(_ metaAccount: ManagedMetaAccountModel) -> Bool {
        guard let chainAccount = metaAccount.info.proxyChainAccount(chainId: chainModel.chainId) else {
            return false
        }

        return chainAccount.proxy != nil
    }

    func canHandle(_ delegatedAccount: any DiscoveredDelegatedAccountProtocol) -> Bool {
        delegatedAccount is ProxiedAccount
    }
}

enum DelegatedAccountError: Error {
    case invalidAccountType
    case callHashNotFound
}
