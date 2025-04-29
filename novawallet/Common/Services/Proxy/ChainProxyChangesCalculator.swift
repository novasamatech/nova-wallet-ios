import Foundation

struct ChainProxyChangesCalculator {
    struct ProxyIdentifier: Hashable {
        let proxiedAccountId: AccountId
        let proxyAccountId: AccountId
        let proxyType: Proxy.ProxyType
    }

    struct ProxiedMetaAccount {
        let proxy: ProxyAccountModel
        let metaAccount: ManagedMetaAccountModel
    }

    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }

    func calculateUpdates(
        from remoteProxieds: [ProxiedAccountId: [ProxyAccount]],
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let localProxies = chainMetaAccounts.reduce(into: [ProxyIdentifier: ProxiedMetaAccount]()) { result, item in
            if let chainAccount = item.info.proxyChainAccount(chainId: chainModel.chainId),
               let proxy = chainAccount.proxy {
                let proxyId = ProxyIdentifier(
                    proxiedAccountId: chainAccount.accountId,
                    proxyAccountId: proxy.accountId,
                    proxyType: proxy.type
                )
                result[proxyId] = .init(proxy: proxy, metaAccount: item)
            }
        }

        let allProxieds = Set(remoteProxieds.map(\.key) + localProxies.map(\.key.proxiedAccountId))

        let changes = try allProxieds.map { accountId in
            let localProxiesForProxied = localProxies.filter { $0.key.proxiedAccountId == accountId }
            let remoteProxies = remoteProxieds[accountId] ?? []

            return try calculateUpdates(
                for: localProxiesForProxied,
                from: remoteProxies,
                accountId: accountId,
                identities: identities
            )
        }

        return SyncChanges(
            newOrUpdatedItems: changes.flatMap(\.newOrUpdatedItems),
            removedItems: changes.flatMap(\.removedItems)
        )
    }

    func calculateUpdates(
        for localProxies: [ProxyIdentifier: ProxiedMetaAccount],
        from remoteProxies: [ProxyAccount],
        accountId: ProxiedAccountId,
        identities: [ProxiedAccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let updatedProxiedMetaAccounts = try remoteProxies.reduce(into: [ManagedMetaAccountModel]()) { result, proxy in
            let key = ProxyIdentifier(
                proxiedAccountId: accountId,
                proxyAccountId: proxy.accountId,
                proxyType: proxy.type
            )

            if let localProxy = localProxies[key] {
                guard localProxy.proxy.status == .revoked else {
                    return
                }

                let newInfo = localProxy.metaAccount.info.replacingProxy(
                    chainId: chainModel.chainId,
                    proxy: localProxy.proxy.replacingStatus(.new)
                )
                let updatedItem = localProxy.metaAccount.replacingInfo(newInfo)
                result.append(updatedItem)
            } else {
                let cryptoType: MultiassetCryptoType = !chainModel.isEthereumBased ? .sr25519 : .ethereumEcdsa

                let chainAccountModel = ChainAccountModel(
                    chainId: chainModel.chainId,
                    accountId: accountId,
                    publicKey: accountId,
                    cryptoType: cryptoType.rawValue,
                    proxy: .init(type: proxy.type, accountId: proxy.accountId, status: .new),
                    multisig: nil
                )

                let name = try identities[accountId]?.displayName ?? accountId.toAddress(using: chainModel.chainFormat)
                let newWallet = ManagedMetaAccountModel(info: MetaAccountModel(
                    metaId: UUID().uuidString,
                    name: name,
                    substrateAccountId: nil,
                    substrateCryptoType: nil,
                    substratePublicKey: nil,
                    ethereumAddress: nil,
                    ethereumPublicKey: nil,
                    chainAccounts: [chainAccountModel],
                    type: .proxied
                ))

                result.append(newWallet)
            }
        }
        let revokedProxiedMetaAccounts = localProxies.filter { localProxy in
            !remoteProxies.contains {
                localProxy.key.proxiedAccountId == accountId &&
                    localProxy.key.proxyType == $0.type &&
                    localProxy.key.proxyAccountId == $0.accountId
            }
        }.map { localProxy in
            let newInfo = localProxy.value.metaAccount.info.replacingProxy(
                chainId: chainModel.chainId,
                proxy: localProxy.value.proxy.replacingStatus(.revoked)
            )
            let updatedItem = localProxy.value.metaAccount.replacingInfo(newInfo)
            return updatedItem
        }

        return .init(newOrUpdatedItems: updatedProxiedMetaAccounts + revokedProxiedMetaAccounts)
    }
}
