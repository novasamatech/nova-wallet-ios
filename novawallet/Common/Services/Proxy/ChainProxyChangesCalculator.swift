import Foundation

struct ChainProxyChangesCalculator {
    struct ProxidIdentifier: Hashable {
        let accountId: AccountId
        let proxyType: Proxy.ProxyType
    }

    struct ProxidValue {
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
    ) -> SyncChanges<ManagedMetaAccountModel> {
        let localProxies = chainMetaAccounts.reduce(into: [ProxidIdentifier: ProxidValue]()) { result, item in
            if let chainAccount = item.info.proxyChainAccount(chainId: chainModel.chainId),
               let proxy = chainAccount.proxy {
                result[.init(accountId: chainAccount.accountId, proxyType: proxy.type)] = .init(proxy: proxy, metaAccount: item)
            }
        }

        let changes = remoteProxieds.map { accountId, remoteProxies in
            calculateUpdates(
                for: localProxies,
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
        for localProxies: [ProxidIdentifier: ProxidValue],
        from remoteProxies: [ProxyAccount],
        accountId: ProxiedAccountId,
        identities: [ProxiedAccountId: AccountIdentity]
    ) -> SyncChanges<ManagedMetaAccountModel> {
        let updatedProxiedMetaAccounts = remoteProxies.reduce(into: [ManagedMetaAccountModel]()) { result, proxy in
            let key = ProxidIdentifier(accountId: accountId, proxyType: proxy.type)
            if let localProxy = localProxies[key] {
                if localProxy.proxy.status == .revoked {
                    let updatedItem = localProxy.metaAccount.replacingInfo(localProxy.metaAccount.info.replacingProxy(
                        chainId: chainModel.chainId,
                        proxy: localProxy.proxy.replacingStatus(.new)
                    ))
                    result.append(updatedItem)
                } else {
                    return
                }
            } else {
                let cryptoType: MultiassetCryptoType = !chainModel.isEthereumBased ? .sr25519 : .ethereumEcdsa

                let chainAccountModel = ChainAccountModel(
                    chainId: chainModel.chainId,
                    accountId: accountId,
                    publicKey: accountId,
                    cryptoType: cryptoType.rawValue,
                    proxy: .init(type: proxy.type, accountId: proxy.accountId, status: .new)
                )

                let newWallet = ManagedMetaAccountModel(info: MetaAccountModel(
                    metaId: UUID().uuidString,
                    name: identities[accountId]?.displayName ?? accountId.toHexString(),
                    substrateAccountId: accountId,
                    substrateCryptoType: cryptoType.rawValue,
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
                localProxy.key.accountId == accountId && localProxy.key.proxyType == $0.type && localProxy.value.proxy.accountId == $0.accountId
            }
        }.map { localProxy in
            let updatedItem = localProxy.value.metaAccount.replacingInfo(localProxy.value.metaAccount.info.replacingProxy(
                chainId: chainModel.chainId,
                proxy: localProxy.value.proxy.replacingStatus(.revoked)
            ))
            return updatedItem
        }

        return .init(newOrUpdatedItems: updatedProxiedMetaAccounts + revokedProxiedMetaAccounts)
    }
}
