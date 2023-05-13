import Foundation

extension BalancesStore {
    static func createDefault() -> BalancesStore? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        return BalancesStore(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactory.shared
        )
    }
}
