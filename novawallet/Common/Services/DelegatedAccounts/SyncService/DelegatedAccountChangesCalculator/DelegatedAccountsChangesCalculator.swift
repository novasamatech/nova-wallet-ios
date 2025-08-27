import Foundation

protocol DelegatedAccountsChangesCalculatorProtocol {
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
        updatedMetaAccounts: [ManagedMetaAccountModel],
        remoteDelegatedAccounts: [DiscoveredDelegatedAccountProtocol]
    ) -> [ManagedMetaAccountModel] {
        let updatedDelegatedAccounts = buildLocalDelegatedAccountsMap(from: updatedMetaAccounts)

        let revokedAccounts: [ManagedMetaAccountModel] = updatedDelegatedAccounts
            .values
            .reduce(into: []) { acc, metaAccount in
                guard
                    let factory = getFactoryForMetaAccount(metaAccount),
                    !remoteDelegatedAccounts.contains(
                        where: { factory.matchesDelegatedAccount(metaAccount, delegatedAccount: $0) }
                    )
                else { return }

                let revokedAccount = factory.markAsRevoked(metaAccount)

                acc.append(revokedAccount)
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

extension DelegatedAccountsChangesCalculator: DelegatedAccountsChangesCalculatorProtocol {
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

        let revokedAccounts = findRevokedAccounts(
            updatedMetaAccounts: updatedMetaAccounts,
            remoteDelegatedAccounts: remoteDelegatedAccounts.flatMap(\.accounts)
        )

        return SyncChanges(
            newOrUpdatedItems: updatedMetaAccounts + revokedAccounts,
            removedItems: []
        )
    }
}
