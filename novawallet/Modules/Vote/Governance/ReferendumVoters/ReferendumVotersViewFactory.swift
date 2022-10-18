import Foundation
import SubstrateSdk
import RobinHood
import SoraFoundation

struct ReferendumVotersViewFactory {
    static func createView(
        state: GovernanceSharedState,
        referendum: ReferendumLocal,
        type: ReferendumVotersType
    ) -> ReferendumVotersViewProtocol? {
        guard
            let interactor = createInteractor(for: state, referendum: referendum),
            let chain = state.settings.value
        else {
            return nil
        }

        let wireframe = ReferendumVotersWireframe()

        let localizationManager = LocalizationManager.shared

        let stringViewModelFactory = ReferendumDisplayStringFactory(
            formatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = ReferendumVotersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            type: type,
            referendum: referendum,
            chain: chain,
            stringFactory: stringViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ReferendumVotersViewController(
            presenter: presenter,
            votersType: type,
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: GovernanceSharedState,
        referendum: ReferendumLocal
    ) -> ReferendumVotersInteractor? {
        guard let chain = state.settings.value else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationQueue()

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let referendumsOperationFactory = Gov2OperationFactory(requestFactory: requestFactory)
        let identityOperationFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        return ReferendumVotersInteractor(
            referendumIndex: referendum.index,
            chain: chain,
            referendumsOperationFactory: referendumsOperationFactory,
            identityOperationFactory: identityOperationFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue
        )
    }
}
