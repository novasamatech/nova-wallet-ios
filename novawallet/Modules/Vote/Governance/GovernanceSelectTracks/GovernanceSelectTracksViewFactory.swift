import Foundation
import SoraFoundation

struct GovernanceSelectTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegate _: AccountId
    ) -> GovernanceSelectTracksViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovernanceSelectTracksWireframe()

        let presenter = GovernanceSelectTracksPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = GovernanceSelectTracksViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(for state: GovernanceSharedState) -> GovernanceSelectTracksInteractor? {
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
