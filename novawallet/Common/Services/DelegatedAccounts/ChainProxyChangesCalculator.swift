import Foundation

struct ChainProxyChangesCalculator {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

// MARK: - Private structs

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

// MARK: - Private

private extension ChainProxyChangesCalculator {
    // MARK: Multisig update

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
            let updatedMultisigMetaAccount = updateMultisigStatus(for: localMultisig)
            metaAccounts.append(updatedMultisigMetaAccount.metaAccount)
        } else {
            let newMultisigMetaAccount = try createMultisigMetaAccount(
                multisig: multisig,
                accountId: accountId,
                using: identities
            )
            metaAccounts.append(newMultisigMetaAccount)
        }
    }

    func updateMultisigStatus(
        for localMultisigMetaAccount: MultisigMetaAccount
    ) -> MultisigMetaAccount {
        let chainAccount = localMultisigMetaAccount.metaAccount.info
            .multisigAccount()?
            .multisig
            .chainAccount
        let updatedMultisig = localMultisigMetaAccount.multisig.replacingStatus(.pending)

        guard
            let chainAccount,
            let newInfo = localMultisigMetaAccount.metaAccount.info.replacingMultisig(
                with: .singleChain(
                    chainAccount: chainAccount,
                    multisig: updatedMultisig
                )
            )
        else {
            return localMultisigMetaAccount
        }

        let updatedMultisigMetaAccount = localMultisigMetaAccount
            .metaAccount
            .replacingInfo(newInfo)

        return MultisigMetaAccount(
            multisig: updatedMultisig,
            metaAccount: updatedMultisigMetaAccount
        )
    }

    func createMultisigMetaAccount(
        multisig: DiscoveredMultisig,
        accountId: AccountId,
        using identities: [AccountId: AccountIdentity]
    ) throws -> ManagedMetaAccountModel {
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

        return newWallet
    }

    // MARK: Proxy update

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

    // MARK: Calculate

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

// MARK: - Internal

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
            guard let multisigAccountType = item.info.multisigAccount() else {
                return
            }

            let (chainAccount, multisig) = multisigAccountType.multisig

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
