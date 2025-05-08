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

    func calculateUpdates(
        for localProxies: [ProxyIdentifier: ProxiedMetaAccount],
        localMultisigs: [MultisigIdentifier: MultisigMetaAccount],
        from remoteDelegatedAccounts: [DelegatedAccount],
        accountId: AccountId,
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let updatedDelegatedMetaAccounts = try remoteDelegatedAccounts
            .reduce(into: [ManagedMetaAccountModel]()) { result, account in
                switch account {
                case let .proxy(proxy):
                    try addUpdated(
                        proxy: proxy,
                        to: &result,
                        for: accountId,
                        basedOn: localProxies,
                        identities: identities
                    )
                case let .multisig(multisig):
                    try addUpdated(
                        multisig: multisig,
                        to: &result,
                        for: accountId,
                        basedOn: localMultisigs,
                        identities: identities
                    )
                }
            }

        let revokedProxiedMetaAccounts = localProxies.filter { localProxy in
            !remoteDelegatedAccounts
                .compactMap(\.proxy)
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

        let resolvedMultisigMetaAccounts = localMultisigs.filter { localMultisig in
            !remoteDelegatedAccounts
                .compactMap(\.multisig)
                .contains {
                    localMultisig.key.multisigAccountId == $0.accountId &&
                        localMultisig.key.signatoryAccountId == accountId
                }
        }

        return .init(
            newOrUpdatedItems: updatedDelegatedMetaAccounts + revokedProxiedMetaAccounts,
            removedItems: resolvedMultisigMetaAccounts.map(\.value.metaAccount)
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
            if
                let chainAccount = item.info.multisigChainAccount(chainId: chainModel.chainId),
                let multisig = chainAccount.multisig {
                let multisigId = MultisigIdentifier(
                    signatoryAccountId: chainAccount.accountId,
                    multisigAccountId: multisig.accountId
                )

                result[multisigId] = .init(multisig: multisig, metaAccount: item)
            } else if let multisig = item.info.multisig, let signatoryAccountId = item.info.substrateAccountId {
                let multisigId = MultisigIdentifier(
                    signatoryAccountId: signatoryAccountId,
                    multisigAccountId: multisig.accountId
                )
                result[multisigId] = .init(multisig: multisig, metaAccount: item)
            }
        }

        let allDelegatedAccounts = Set(
            remoteDelegatedAccounts.map(\.key)
                + localProxies.map(\.key.proxiedAccountId)
                + localMultisigs.map(\.key.signatoryAccountId)
        )

        let changes = try allDelegatedAccounts.map { accountId in
            let localProxiesForProxied = localProxies.filter { $0.key.proxiedAccountId == accountId }
            let localMultisigForSignatory = localMultisigs.filter { $0.key.signatoryAccountId == accountId }
            let remoteDelegatedAccounts = remoteDelegatedAccounts[accountId] ?? []

            return try calculateUpdates(
                for: localProxiesForProxied,
                localMultisigs: localMultisigForSignatory,
                from: remoteDelegatedAccounts,
                accountId: accountId,
                identities: identities
            )
        }

        return SyncChanges(
            newOrUpdatedItems: changes.flatMap(\.newOrUpdatedItems),
            removedItems: changes.flatMap(\.removedItems)
        )
    }
}
