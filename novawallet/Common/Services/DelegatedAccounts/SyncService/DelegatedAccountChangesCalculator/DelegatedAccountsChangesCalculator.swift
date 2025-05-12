import Foundation

protocol DelegatedAccountsChangesCalcualtorProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: [AccountId: [DelegatedAccountProtocol]],
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel>
}

class DelegatedAccountsChangesCalculator {
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
        for delegatorAccountId: AccountId,
        remoteDelegatedAccounts: [DelegatedAccountProtocol],
        localDelegatedAccounts: [DelegateIdentifier: ManagedMetaAccountModel],
        localMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let updatedMetaAccounts = try remoteDelegatedAccounts.compactMap { remoteDelegatedAccount in
            try processRemoteDelegatedAccount(
                remoteDelegatedAccount,
                delegatorAccountId: delegatorAccountId,
                localDelegatedAccounts: localDelegatedAccounts,
                localMetaAccounts: localMetaAccounts,
                identities: identities
            )
        }

        let revokedAccounts = findRevokedAccounts(
            for: delegatorAccountId,
            remoteDelegatedAccounts: remoteDelegatedAccounts,
            localDelegatedAccounts: localDelegatedAccounts
        )

        return SyncChanges(
            newOrUpdatedItems: updatedMetaAccounts + revokedAccounts.values,
            removedItems: []
        )
    }

    func processRemoteDelegatedAccount(
        _ delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId,
        localDelegatedAccounts: [DelegateIdentifier: ManagedMetaAccountModel],
        localMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> ManagedMetaAccountModel? {
        guard let factory = getFactoryForDelegatedAccount(delegatedAccount) else {
            return nil
        }

        let existingMetaAccount = findExistingMetaAccount(
            for: delegatedAccount,
            delegatorAccountId: delegatorAccountId,
            in: localDelegatedAccounts,
            using: factory
        )

        return if let existingMetaAccount {
            factory.renew(existingMetaAccount)
        } else {
            try factory.createMetaAccount(
                for: delegatedAccount,
                delegatorAccountId: delegatorAccountId,
                using: identities,
                localMetaAccounts: localMetaAccounts
            )
        }
    }

    func findExistingMetaAccount(
        for delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId,
        in localDelegatedAccounts: [DelegateIdentifier: ManagedMetaAccountModel],
        using factory: DelegatedMetaAccountFactoryProtocol
    ) -> ManagedMetaAccountModel? {
        localDelegatedAccounts.first { id, metaAccount in
            id.delegatorAccountId == delegatorAccountId &&
                factory.matchesDelegatedAccount(
                    metaAccount,
                    delegatedAccount: delegatedAccount,
                    delegatorAccountId: delegatorAccountId
                )
        }?.value
    }

    func findRevokedAccounts(
        for delegatorAccountId: AccountId,
        remoteDelegatedAccounts: [DelegatedAccountProtocol],
        localDelegatedAccounts: [DelegateIdentifier: ManagedMetaAccountModel]
    ) -> [DelegateIdentifier: ManagedMetaAccountModel] {
        let relevantLocalAccounts = localDelegatedAccounts.filter {
            $0.key.delegatorAccountId == delegatorAccountId
        }

        let revokedAccounts = relevantLocalAccounts.filter { _, metaAccount in
            guard let factory = getFactoryForMetaAccount(metaAccount) else { return false }

            return !remoteDelegatedAccounts.contains { remoteDelegatedAccount in
                factory.matchesDelegatedAccount(
                    metaAccount,
                    delegatedAccount: remoteDelegatedAccount,
                    delegatorAccountId: delegatorAccountId
                )
            }
        }

        return revokedAccounts
    }

    func getFactoryForDelegatedAccount(
        _ delegatedAccount: DelegatedAccountProtocol
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
        from remoteDelegatedAccounts: [AccountId: [DelegatedAccountProtocol]],
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> SyncChanges<ManagedMetaAccountModel> {
        let localDelegatedAccounts = buildLocalDelegatedAccountsMap(from: chainMetaAccounts)

        let delegatorAccountIds = Set(remoteDelegatedAccounts.keys)
            .union(localDelegatedAccounts.keys.map(\.delegatorAccountId))

        let changes = try delegatorAccountIds.map { delegatorAccountId in
            try calculateUpdates(
                for: delegatorAccountId,
                remoteDelegatedAccounts: remoteDelegatedAccounts[delegatorAccountId] ?? [],
                localDelegatedAccounts: localDelegatedAccounts,
                localMetaAccounts: chainMetaAccounts,
                identities: identities
            )
        }

        return SyncChanges(
            newOrUpdatedItems: changes.flatMap(\.newOrUpdatedItems),
            removedItems: changes.flatMap(\.removedItems)
        )
    }
}
