import Foundation
import SubstrateSdk
import RobinHood

struct ReferendumDetailsViewFactory {
    static func createView(
        for referendum: ReferendumLocal,
        state: GovernanceSharedState
    ) -> ReferendumDetailsViewProtocol? {
        guard let interactor = createInteractor(for: referendum, state: state) else {
            return nil
        }

        let wireframe = ReferendumDetailsWireframe()

        let presenter = ReferendumDetailsPresenter(interactor: interactor, wireframe: wireframe)

        let view = ReferendumDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for referendum: ReferendumLocal,
        state: GovernanceSharedState
    ) -> ReferendumDetailsInteractor? {
        guard let chain = state.settings.value else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
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
            chain: chain,
            actionDetailsOperationFactory: actionDetailsOperationFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            identityOperationFactory: identityOperationFactory
        )
    }
}
