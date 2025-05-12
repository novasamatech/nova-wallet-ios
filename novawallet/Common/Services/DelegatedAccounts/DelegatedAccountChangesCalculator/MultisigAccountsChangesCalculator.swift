import Foundation

class MultisigAccountsChangesCalculator {
    let chainModel: ChainModel

    init(chainModel: ChainModel) {
        self.chainModel = chainModel
    }
}

// MARK: - Private structs

private extension MultisigAccountsChangesCalculator {
    struct MultisigIdentifier: Hashable {
        let signatoryAccountId: AccountId
        let multisigAccountId: AccountId
    }

    struct MultisigMetaAccount {
        let multisig: MultisigModel
        let metaAccount: ManagedMetaAccountModel
    }
}

// MARK: - Private

private extension MultisigAccountsChangesCalculator {
    func calculateChanges(
        for remoteDelegatedAccounts: [AccountId: [DelegatedAccountProtocol]],
        localMultisigs: [MultisigIdentifier: MultisigMetaAccount],
        using identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let remoteMultisigAccountIds = remoteDelegatedAccounts
            .filter { $0.value.contains { $0 is DiscoveredMultisig } }.keys

        let multisigAccountIds = Set(remoteMultisigAccountIds + localMultisigs.map(\.key.signatoryAccountId))

        let changes = try multisigAccountIds.map { accountId in
            let localMultisigsForSignatory = localMultisigs.filter { $0.key.signatoryAccountId == accountId }
            let remoteDelegatedAccounts = remoteDelegatedAccounts[accountId] ?? []

            return try calculateMultisigUpdates(
                for: localMultisigsForSignatory,
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

    func calculateMultisigUpdates(
        for localMultisigs: [MultisigIdentifier: MultisigMetaAccount],
        from remoteDelegatedAccounts: [DelegatedAccountProtocol],
        accountId: AccountId,
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let remoteMultisigAccounts = remoteDelegatedAccounts
            .compactMap { $0 as? DiscoveredMultisig }

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
}

// MARK: - DelegatedAccountsChangesCalcualtorProtocol

extension MultisigAccountsChangesCalculator: DelegatedAccountsChangesCalcualtorProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: [AccountId: [DelegatedAccountProtocol]],
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
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
            localMultisigs: localMultisigs,
            using: identities
        )
    }
}
