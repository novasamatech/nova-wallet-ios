import Foundation

protocol DelegatedAccountsChangesCalculatorProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: [DiscoveredDelegatedAccountProtocol],
        initialMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) -> SyncChanges<ManagedMetaAccountModel>
}

final class DelegatedAccountsChangesCalculator {
    let chainIds: Set<ChainModel.Id>
    let chainRegistry: ChainRegistryProtocol
    let logger: LoggerProtocol

    init(
        chainIds: Set<ChainModel.Id>,
        chainRegistry: ChainRegistryProtocol,
        logger: LoggerProtocol
    ) {
        self.chainIds = chainIds
        self.chainRegistry = chainRegistry
        self.logger = logger
    }
}

// MARK: - Private

private extension DelegatedAccountsChangesCalculator {
    private func resolveFactory() -> CompoundDelegatedMetaAccountFactory {
        let chains = chainIds.compactMap { chainRegistry.getChain(for: $0) }

        return CompoundDelegatedMetaAccountFactory(chains: chains, logger: logger)
    }

    func createOrRenewWallets(
        for remoteDelegatedAccounts: [DiscoveredDelegatedAccountProtocol],
        factory: CompoundDelegatedMetaAccountFactory,
        localDelegatedWallets: [DelegateIdentifier: ManagedMetaAccountModel],
        initialLocalNonDelegatedWallets: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) -> [ManagedMetaAccountModel] {
        remoteDelegatedAccounts.reduce([]) { updatedDelegatedWallets, delegatedAccount in
            // we intentionally don't add local delegated wallets since they might be revoked
            let context = DelegatedMetaAccountFactoryContext(
                identities: identities,
                metaAccounts: initialLocalNonDelegatedWallets + updatedDelegatedWallets
            )

            let delegatedWallets = factory.createMetaAccount(
                for: delegatedAccount,
                context: context
            )

            let newOrUpdatedWallets: [ManagedMetaAccountModel] = delegatedWallets.compactMap { delegatedWallet in
                guard let delegatedWalletId = delegatedWallet.info.getDelegateIdentifier() else {
                    logger.error("Expected identifier can't be created")
                    return nil
                }

                guard let existingLocalWallet = localDelegatedWallets[delegatedWalletId] else {
                    return delegatedWallet
                }

                if let renewedWallet = existingLocalWallet.renew() {
                    return renewedWallet
                } else {
                    return existingLocalWallet
                }
            }

            return updatedDelegatedWallets + newOrUpdatedWallets
        }
    }

    func revokeWalletsIfNeeded(
        _ localDelegatedWallets: [ManagedMetaAccountModel],
        basedOn newOrUpdatedDelegatedWallets: [ManagedMetaAccountModel]
    ) -> [ManagedMetaAccountModel] {
        let indexedNewOrUpdatedWallets = newOrUpdatedDelegatedWallets.indexDelegatedAccounts()

        let revokedWallets: [ManagedMetaAccountModel] = localDelegatedWallets.compactMap { localDelegatedWallet in
            guard
                let delegateIdentifier = localDelegatedWallet.info.getDelegateIdentifier(),
                indexedNewOrUpdatedWallets[delegateIdentifier] == nil else {
                return nil
            }

            return localDelegatedWallet.markAsRevoked()
        }

        return revokedWallets
    }
}

// MARK: - DelegatedAccountsChangesCalcualtorProtocol

extension DelegatedAccountsChangesCalculator: DelegatedAccountsChangesCalculatorProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: [DiscoveredDelegatedAccountProtocol],
        initialMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) -> SyncChanges<ManagedMetaAccountModel> {
        let initialDelegatedWallets = initialMetaAccounts.indexDelegatedAccounts()
        let initialNonDelegatedWallets = initialMetaAccounts.filter { !$0.info.isDelegated() }

        let newOrRenewedWallets = createOrRenewWallets(
            for: remoteDelegatedAccounts,
            factory: resolveFactory(),
            localDelegatedWallets: initialDelegatedWallets,
            initialLocalNonDelegatedWallets: initialNonDelegatedWallets,
            identities: identities
        )

        let revokedWallets = revokeWalletsIfNeeded(
            initialMetaAccounts.filter { $0.info.isDelegated() },
            basedOn: newOrRenewedWallets
        )

        return SyncChanges(newOrUpdatedItems: newOrRenewedWallets + revokedWallets, removedItems: [])
    }
}
