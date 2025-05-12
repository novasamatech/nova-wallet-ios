import Foundation

class ProxyAccountsChangesCalculator {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

// MARK: - Private structs

private extension ProxyAccountsChangesCalculator {
    struct ProxyIdentifier: Hashable {
        let proxiedAccountId: AccountId
        let proxyAccountId: AccountId
        let proxyType: Proxy.ProxyType
    }

    struct ProxiedMetaAccount {
        let proxy: ProxyAccountModel
        let metaAccount: ManagedMetaAccountModel
    }
}

// MARK: - Private

private extension ProxyAccountsChangesCalculator {
    func calculateChanges(
        for remoteDelegatedAccounts: [AccountId: [DelegatedAccountProtocol]],
        localProxies: [ProxyIdentifier: ProxiedMetaAccount],
        using identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let remoteProxiedAccountIds = remoteDelegatedAccounts
            .filter { $0.value.contains { $0 is ProxyAccount } }.keys

        let proxiedAccountIds = Set(remoteProxiedAccountIds + localProxies.map(\.key.proxiedAccountId))

        let changes = try proxiedAccountIds.map { accountId in
            let localProxiesForProxied = localProxies.filter { $0.key.proxiedAccountId == accountId }
            let remoteProxyAccounts = remoteDelegatedAccounts[accountId]?
                .compactMap { $0 as? ProxyAccount } ?? []

            return try calculateProxyUpdates(
                for: localProxiesForProxied,
                from: remoteProxyAccounts,
                accountId: accountId,
                identities: identities
            )
        }

        return SyncChanges(
            newOrUpdatedItems: changes.flatMap(\.newOrUpdatedItems),
            removedItems: changes.flatMap(\.removedItems)
        )
    }

    func calculateProxyUpdates(
        for localProxies: [ProxyIdentifier: ProxiedMetaAccount],
        from remoteProxyAccounts: [ProxyAccount],
        accountId: AccountId,
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let updatedProxyAccounts = try remoteProxyAccounts
            .reduce(into: [ManagedMetaAccountModel]()) { result, proxy in
                try addUpdated(
                    proxy: proxy,
                    to: &result,
                    for: accountId,
                    basedOn: localProxies,
                    identities: identities
                )
            }
        let revokedProxiedMetaAccounts = localProxies.filter { localProxy in
            !remoteProxyAccounts
                .contains {
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

        return SyncChanges(
            newOrUpdatedItems: updatedProxyAccounts + revokedProxiedMetaAccounts,
            removedItems: []
        )
    }

    func addUpdated(
        proxy: ProxyAccount,
        to metaAccounts: inout [ManagedMetaAccountModel],
        for accountId: AccountId,
        basedOn localProxies: [ProxyIdentifier: ProxiedMetaAccount],
        identities: [AccountId: AccountIdentity]
    ) throws {
        let key = ProxyIdentifier(
            proxiedAccountId: accountId,
            proxyAccountId: proxy.accountId,
            proxyType: proxy.type
        )

        if let localProxied = localProxies[key] {
            let updatedProxied = updateProxyStatus(for: localProxied)
            metaAccounts.append(updatedProxied.metaAccount)
        } else {
            let newProxiedMetaAccount = try createProxiedMetaAccount(
                proxy: proxy,
                accountId: accountId,
                using: identities
            )
            metaAccounts.append(newProxiedMetaAccount)
        }
    }

    func updateProxyStatus(for localProxied: ProxiedMetaAccount) -> ProxiedMetaAccount {
        guard localProxied.proxy.status == .revoked else {
            return localProxied
        }

        let updatedProxy = localProxied.proxy.replacingStatus(.new)

        let newInfo = localProxied.metaAccount.info.replacingProxy(
            chainId: chainModel.chainId,
            proxy: updatedProxy
        )
        let updatedItem = localProxied.metaAccount.replacingInfo(newInfo)

        return ProxiedMetaAccount(
            proxy: updatedProxy,
            metaAccount: updatedItem
        )
    }

    func createProxiedMetaAccount(
        proxy: ProxyAccount,
        accountId: AccountId,
        using identities: [AccountId: AccountIdentity]
    ) throws -> ManagedMetaAccountModel {
        let cryptoType: MultiassetCryptoType = !chainModel.isEthereumBased ? .sr25519 : .ethereumEcdsa

        let chainAccountModel = ChainAccountModel(
            chainId: chainModel.chainId,
            accountId: accountId,
            publicKey: accountId,
            cryptoType: cryptoType.rawValue,
            proxy: .init(type: proxy.type, accountId: proxy.accountId, status: .new),
            multisig: nil
        )

        let name = try identities[accountId]?.displayName
            ?? accountId.toAddress(using: chainModel.chainFormat)

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

// MARK: - DelegatedAccountsChangesCalcualtorProtocol

extension ProxyAccountsChangesCalculator: DelegatedAccountsChangesCalcualtorProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: [AccountId: [DelegatedAccountProtocol]],
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

        return try calculateChanges(
            for: remoteDelegatedAccounts,
            localProxies: localProxies,
            using: identities
        )
    }
}
