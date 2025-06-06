import Foundation

protocol DelegatedAccountsChangesCalcualtorProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: DelegatedAccountsByDelegate,
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel>
}

final class DelegatedAccountsChangesCalculator {
    let chainModel: ChainModel
    let factories: [DelegatedMetaAccountFactoryProtocol]

    init(
        chainModel: ChainModel,
        factories: [DelegatedMetaAccountFactoryProtocol]
    ) {
        self.chainModel = chainModel
        self.factories = factories
    }

    convenience init(chainModel: ChainModel) {
        let factories: [DelegatedMetaAccountFactoryProtocol] = [
            ProxyMetaAccountFactory(chainModel: chainModel),
            MultisigMetaAccountFactory(chainModel: chainModel)
        ]
        self.init(chainModel: chainModel, factories: factories)
    }
}

// MARK: - Private

private extension DelegatedAccountsChangesCalculator {
    func buildLocalDelegatedAccountsMap(
        from chainMetaAccounts: [ManagedMetaAccountModel]
    ) -> [DelegateIdentifier: ManagedMetaAccountModel] {
        chainMetaAccounts.reduce(into: [:]) { acc, metaAccount in
            factories
                .filter { $0.canHandle(metaAccount) }
                .forEach { factory in
                    if let identifier = factory.extractDelegateIdentifier(from: metaAccount) {
                        acc[identifier] = metaAccount
                    }
                }
        }
    }

    func calculateUpdates(
        for delegateAccountId: AccountId,
        remoteDelegatedAccounts: [DiscoveredDelegatedAccountProtocol],
        localDelegatedAccounts: [DelegateIdentifier: ManagedMetaAccountModel],
        localMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let updatedMetaAccounts = try processRemoteDelegatedAccounts(
            remoteDelegatedAccounts,
            localDelegatedAccounts: localDelegatedAccounts,
            localMetaAccounts: localMetaAccounts,
            identities: identities
        )

        let revokedAccounts = findRevokedAccounts(
            for: delegateAccountId,
            updatedDelegatedAccounts: updatedMetaAccounts,
            localDelegatedAccounts: Array(localDelegatedAccounts.values)
        )

        return SyncChanges(
            newOrUpdatedItems: updatedMetaAccounts + revokedAccounts,
            removedItems: []
        )
    }

    func processRemoteDelegatedAccounts(
        _ remoteDelegatedAccounts: [DiscoveredDelegatedAccountProtocol],
        localDelegatedAccounts: [DelegateIdentifier: ManagedMetaAccountModel],
        localMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> [ManagedMetaAccountModel] {
        try remoteDelegatedAccounts.reduce(localMetaAccounts) { updatedMetaAccounts, delegatedAccount in
            guard let factory = getFactoryForDelegatedAccount(delegatedAccount) else {
                return updatedMetaAccounts
            }

            let existingMetaAccount = findExistingMetaAccount(
                for: delegatedAccount,
                in: localDelegatedAccounts,
                using: factory
            )

            let delegatedMetaAccount = if let existingMetaAccount {
                factory.renew(existingMetaAccount)
            } else {
                try factory.createMetaAccount(
                    for: delegatedAccount,
                    using: identities,
                    metaAccounts: updatedMetaAccounts
                )
            }

            return updatedMetaAccounts + [delegatedMetaAccount].compactMap { $0 }
        }
    }

    func findExistingMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        in localDelegatedAccounts: [DelegateIdentifier: ManagedMetaAccountModel],
        using factory: DelegatedMetaAccountFactoryProtocol
    ) -> ManagedMetaAccountModel? {
        localDelegatedAccounts.first { id, metaAccount in
            id.delegatorAccountId == delegatedAccount.accountId &&
                factory.matchesDelegatedAccount(
                    metaAccount,
                    delegatedAccount: delegatedAccount
                )
        }?.value
    }

    func findRevokedAccounts(
        for delegateAccountId: AccountId,
        updatedDelegatedAccounts: [ManagedMetaAccountModel],
        localDelegatedAccounts: [ManagedMetaAccountModel]
    ) -> [ManagedMetaAccountModel] {
        let relevantLocalAccounts: [MetaAccountDelegationId: ManagedMetaAccountModel] = localDelegatedAccounts
            .reduce(into: [:]) { acc, metaAccount in
                guard
                    let delegationId = metaAccount.info.delegationId,
                    delegationId.delegateAccountId == delegateAccountId
                else { return }

                acc[delegationId] = metaAccount
            }
        let updatedDelegationIds = updatedDelegatedAccounts.compactMap(\.info.delegationId)

        let revokedAccounts: [ManagedMetaAccountModel] = Set(relevantLocalAccounts.keys)
            .subtracting(Set(updatedDelegationIds))
            .compactMap { delegationId in
                guard
                    let localAccountToRevoke = relevantLocalAccounts[delegationId],
                    let factory = getFactoryForMetaAccount(localAccountToRevoke)
                else { return nil }

                return factory.markAsRevoked(localAccountToRevoke)
            }

        return revokedAccounts
    }

    func getFactoryForDelegatedAccount(
        _ delegatedAccount: DiscoveredDelegatedAccountProtocol
    ) -> DelegatedMetaAccountFactoryProtocol? {
        factories.first { $0.canHandle(delegatedAccount) }
    }

    func getFactoryForMetaAccount(
        _ metaAccount: ManagedMetaAccountModel
    ) -> DelegatedMetaAccountFactoryProtocol? {
        factories.first { $0.canHandle(metaAccount) }
    }
}

// MARK: - DelegatedAccountsChangesCalcualtorProtocol

extension DelegatedAccountsChangesCalculator: DelegatedAccountsChangesCalcualtorProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: DelegatedAccountsByDelegate,
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let localDelegatedAccounts = buildLocalDelegatedAccountsMap(from: chainMetaAccounts)

        let updatedMetaAccounts = try remoteDelegatedAccounts.reduce(
            chainMetaAccounts
        ) { nextMetaAccounts, delegatedAccounts in
            try processRemoteDelegatedAccounts(
                delegatedAccounts.accounts,
                localDelegatedAccounts: localDelegatedAccounts,
                localMetaAccounts: nextMetaAccounts,
                identities: identities
            )
        }

        let revokedAccounts = remoteDelegatedAccounts
            .map {
                findRevokedAccounts(
                    for: $0.delegate,
                    updatedDelegatedAccounts: updatedMetaAccounts,
                    localDelegatedAccounts: Array(localDelegatedAccounts.values)
                )
            }
            .flatMap { $0 }

        return SyncChanges(
            newOrUpdatedItems: updatedMetaAccounts + revokedAccounts,
            removedItems: []
        )
    }
}
