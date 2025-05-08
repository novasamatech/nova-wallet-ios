import Foundation

struct ChainProxyChangesCalculator {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

private extension ChainProxyChangesCalculator {
    struct ProxyIdentifier: Hashable {
        let proxiedAccountId: AccountId
        let proxyAccountId: AccountId
        let proxyType: Proxy.ProxyType
    }

    struct MultisigIdentifier: Hashable {
        let signatoryAccountId: AccountId
        let multisigAccountId: AccountId
    }

    struct ProxiedMetaAccount {
        let proxy: ProxyAccountModel
        let metaAccount: ManagedMetaAccountModel
    }

    struct MultisigMetaAccount {
        let multisig: MultisigModel
        let metaAccount: ManagedMetaAccountModel
    }
}

private extension ChainProxyChangesCalculator {
    func addUpdated(
        multisig: DiscoveredMultisig,
        to metaAccounts: inout [ManagedMetaAccountModel],
        for accountId: AccountId,
        basedOn localMultisigs: [MultisigIdentifier: MultisigMetaAccount],
        identities: [AccountId: AccountIdentity]
    ) throws {
        let key = MultisigIdentifier(
            signatoryAccountId: accountId,
            multisigAccountId: multisig.accountId
        )

        if let localMultisig = localMultisigs[key] {
            let newInfo = localMultisig.metaAccount.info.replacingMultisig(
                chainId: chainModel.chainId,
                multisig: localMultisig.multisig.replacingStatus(.pending)
            )

            let updatedItem = localMultisig.metaAccount.replacingInfo(newInfo)
            metaAccounts.append(updatedItem)
        } else {
            let cryptoType: MultiassetCryptoType = !chainModel.isEthereumBased ? .sr25519 : .ethereumEcdsa

            let multisigModel = MultisigModel(
                accountId: multisig.accountId,
                signatory: accountId,
                otherSignatories: multisig.otherSignatories(than: accountId),
                threshold: multisig.threshold,
                status: .new
            )

            let chainAccountModel = ChainAccountModel(
                chainId: chainModel.chainId,
                accountId: accountId,
                publicKey: accountId,
                cryptoType: cryptoType.rawValue,
                proxy: nil,
                multisig: multisigModel
            )

            let name = try identities[multisig.accountId]?.displayName
                ?? multisig.accountId.toAddress(using: chainModel.chainFormat)

            let newWallet = ManagedMetaAccountModel(info: MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [chainAccountModel],
                type: .multisig,
                multisig: nil
            ))

            metaAccounts.append(newWallet)
        }
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

        if let localProxy = localProxies[key] {
            guard localProxy.proxy.status == .revoked else {
                return
            }

            let newInfo = localProxy.metaAccount.info.replacingProxy(
                chainId: chainModel.chainId,
                proxy: localProxy.proxy.replacingStatus(.new)
            )
            let updatedItem = localProxy.metaAccount.replacingInfo(newInfo)
            metaAccounts.append(updatedItem)
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
                type: .proxied,
                multisig: nil
            ))

            metaAccounts.append(newWallet)
        }
    }

    func calculateProxyUpdates(
        for localProxies: [ProxyIdentifier: ProxiedMetaAccount],
        from remoteDelegatedAccounts: [DelegatedAccount],
        accountId: AccountId,
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let remoteProxyAccounts = remoteDelegatedAccounts
            .compactMap(\.proxy)
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

    func calculateMultisigUpdates(
        for localMultisigs: [MultisigIdentifier: MultisigMetaAccount],
        from remoteDelegatedAccounts: [DelegatedAccount],
        accountId: AccountId,
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let remoteMultisigAccounts = remoteDelegatedAccounts
            .compactMap(\.multisig)

        let updatedMultisigMetaAccounts = try remoteMultisigAccounts
            .reduce(into: [ManagedMetaAccountModel]()) { result, multisig in
                try addUpdated(
                    multisig: multisig,
                    to: &result,
                    for: accountId,
                    basedOn: localMultisigs,
                    identities: identities
                )
            }
        let resolvedMultisigMetaAccounts = localMultisigs.filter { localMultisig in
            !remoteMultisigAccounts
                .contains {
                    localMultisig.key.multisigAccountId == $0.accountId &&
                        localMultisig.key.signatoryAccountId == accountId
                }
        }

        return SyncChanges(
            newOrUpdatedItems: updatedMultisigMetaAccounts,
            removedItems: resolvedMultisigMetaAccounts.map(\.value.metaAccount)
        )
    }

    func calculateChanges(
        for remoteDelegatedAccounts: [AccountId: [DelegatedAccount]],
        localProxies: [ProxyIdentifier: ProxiedMetaAccount],
        localMultisigs: [MultisigIdentifier: MultisigMetaAccount],
        using identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let remoteProxiedAccountIds = remoteDelegatedAccounts
            .filter { $0.value.contains { $0.proxy != nil } }.keys
        let remoteMultisigAccountIds = remoteDelegatedAccounts
            .filter { $0.value.contains { $0.multisig != nil } }.keys

        let proxiedAccountIds = Set(remoteProxiedAccountIds + localProxies.map(\.key.proxiedAccountId))
        let multisigAccountIds = Set(remoteMultisigAccountIds + localMultisigs.map(\.key.signatoryAccountId))

        let proxyChanges = try proxiedAccountIds.map { accountId in
            let localProxiesForProxied = localProxies.filter { $0.key.proxiedAccountId == accountId }
            let remoteDelegatedAccounts = remoteDelegatedAccounts[accountId] ?? []

            return try calculateProxyUpdates(
                for: localProxiesForProxied,
                from: remoteDelegatedAccounts,
                accountId: accountId,
                identities: identities
            )
        }
        let multisigChanges = try multisigAccountIds.map { accountId in
            let localMultisigsForSignatory = localMultisigs.filter { $0.key.signatoryAccountId == accountId }
            let remoteDelegatedAccounts = remoteDelegatedAccounts[accountId] ?? []

            return try calculateMultisigUpdates(
                for: localMultisigsForSignatory,
                from: remoteDelegatedAccounts,
                accountId: accountId,
                identities: identities
            )
        }

        let changes = proxyChanges + multisigChanges

        return SyncChanges(
            newOrUpdatedItems: changes.flatMap(\.newOrUpdatedItems),
            removedItems: changes.flatMap(\.removedItems)
        )
    }
}

extension ChainProxyChangesCalculator {
    func calculateUpdates(
        from remoteDelegatedAccounts: [AccountId: [DelegatedAccount]],
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

        let localMultisigs = chainMetaAccounts.reduce(
            into: [MultisigIdentifier: MultisigMetaAccount]()
        ) { result, item in
            let (chainAccount, multisig) = item.info.multisigAccount().multisig

            guard
                let multisig,
                let chainAccount,
                chainAccount.chainId == chainModel.chainId
            else { return }

            let localMultisigId = MultisigIdentifier(
                signatoryAccountId: chainAccount.accountId,
                multisigAccountId: multisig.accountId
            )
            result[localMultisigId] = .init(multisig: multisig, metaAccount: item)
        }

        return try calculateChanges(
            for: remoteDelegatedAccounts,
            localProxies: localProxies,
            localMultisigs: localMultisigs,
            using: identities
        )
    }
}
