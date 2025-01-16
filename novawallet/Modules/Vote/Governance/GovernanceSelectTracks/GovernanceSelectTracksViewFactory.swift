import Foundation
import Foundation_iOS

struct GovernanceSelectTracksViewFactory {
    static func createInteractor(for state: GovernanceSharedState) -> GovernanceSelectTracksInteractor? {
        guard
            let chain = state.settings.value?.chain,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: chain.accountRequest()),
            let runtimeProvider = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chain.chainId),
            let subscriptionFactory = state.subscriptionFactory,
            let referendumsFactory = state.referendumsOperationFactory else {
            return nil
        }

        return GovernanceSelectTracksInteractor(
            selectedAccount: selectedAccount,
            subscriptionFactory: subscriptionFactory,
            fetchOperationFactory: referendumsFactory,
            runtimeProvider: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
