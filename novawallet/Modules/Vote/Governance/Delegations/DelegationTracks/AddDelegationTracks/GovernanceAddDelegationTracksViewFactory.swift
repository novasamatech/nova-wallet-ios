import Foundation
import Foundation_iOS
import Keystore_iOS

struct GovernanceAddDelegationTracksViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        delegate: GovernanceDelegateFlowDisplayInfo<AccountId>
    ) -> GovernanceSelectTracksViewProtocol? {
        guard
            let interactor = createInteractor(for: state),
            let chain = state.settings.value?.chain else {
            return nil
        }

        let wireframe = GovernanceAddDelegationTracksWireframe(
            state: state,
            delegateDisplayInfo: delegate
        )

        let presenter = GovernanceAddDelegationTracksPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = GovAddDelegationTracksViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createInteractor(for state: GovernanceSharedState) -> GovAddDelegationTracksInteractor? {
        guard
            let chain = state.settings.value?.chain,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(for: chain.accountRequest()),
            let runtimeProvider = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chain.chainId),
            let subscriptionFactory = state.subscriptionFactory,
            let referendumsFactory = state.referendumsOperationFactory else {
            return nil
        }

        return GovAddDelegationTracksInteractor(
            selectedAccount: selectedAccount,
            subscriptionFactory: subscriptionFactory,
            fetchOperationFactory: referendumsFactory,
            runtimeProvider: runtimeProvider,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            settings: SettingsManager.shared
        )
    }
}
