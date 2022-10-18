import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct ReferendumDetailsViewFactory {
    static func createView(
        for referendum: ReferendumLocal,
        state: GovernanceSharedState
    ) -> ReferendumDetailsViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: referendum,
                currencyManager: currencyManager,
                state: state
            ) else {
            return nil
        }

        let wireframe = ReferendumDetailsWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let presenter = ReferendumDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            referendum: referendum,
            chain: state.settings.value,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ReferendumDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for referendum: ReferendumLocal,
        currencyManager: CurrencyManagerProtocol,
        state: GovernanceSharedState
    ) -> ReferendumDetailsInteractor? {
        guard
            let chain = state.settings.value,
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let chainRegistry = state.chainRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let blockTimeService = state.blockTimeService,
            let subscriptionFactory = state.subscriptionFactory else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let actionDetailsOperationFactory = Gov2ActionOperationFactory(
            requestFactory: requestFactory,
            operationQueue: operationQueue
        )

        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        return ReferendumDetailsInteractor(
            referendum: referendum,
            selectedAccount: selectedAccount,
            chain: chain,
            actionDetailsOperationFactory: actionDetailsOperationFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockTimeService: blockTimeService,
            identityOperationFactory: identityOperationFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            govMetadataLocalSubscriptionFactory: state.govMetadataLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
