import Foundation

protocol DelegatedAccountsChangesFacadeProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: DelegatedAccountsByDelegate,
        supportedChains: Set<ChainModel.Id>,
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> [SyncChanges<ManagedMetaAccountModel>]
}

final class DelegatedAccountsChangesFacade {
    let chainRegistry: ChainRegistryProtocol

    init(
        chainRegistry: ChainRegistryProtocol
    ) {
        self.chainRegistry = chainRegistry
    }
}

private extension DelegatedAccountsChangesFacade {
    func deriveCalculators(
        for supportedChains: Set<ChainModel.Id>
    ) throws -> [DelegatedAccountsChangesCalculatorProtocol] {
        try supportedChains.map { chainId in
            let chain = try chainRegistry.getChainOrError(for: chainId)

            return DelegatedAccountsChangesCalculator(chainModel: chain)
        }
    }
}

extension DelegatedAccountsChangesFacade: DelegatedAccountsChangesFacadeProtocol {
    func calculateUpdates(
        from remoteDelegatedAccounts: DelegatedAccountsByDelegate,
        supportedChains: Set<ChainModel.Id>,
        chainMetaAccounts: [ManagedMetaAccountModel],
        identities: [AccountId: AccountIdentity]
    ) throws -> [SyncChanges<ManagedMetaAccountModel>] {
        let calculators = try deriveCalculators(for: supportedChains)

        return try calculators.map { calculator in
            try calculator.calculateUpdates(
                from: remoteDelegatedAccounts,
                chainMetaAccounts: chainMetaAccounts,
                identities: identities
            )
        }
    }
}
