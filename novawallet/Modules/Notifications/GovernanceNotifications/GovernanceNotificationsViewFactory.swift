import Foundation
import Foundation_iOS
import SubstrateSdk
import Operation_iOS

struct GovernanceNotificationsViewFactory {
    static func createView(
        settings: GovernanceNotificationsModel,
        completion: @escaping (GovernanceNotificationsModel) -> Void
    ) -> GovernanceNotificationsViewProtocol? {
        let interactor = createInteractor()

        let wireframe = GovernanceNotificationsWireframe(completion: completion)

        let presenter = GovernanceNotificationsPresenter(
            initState: settings,
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = GovernanceNotificationsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> GovernanceNotificationsInteractor {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let operationFactory = Gov2OperationFactory(
            requestFactory: requestFactory,
            commonOperationFactory: GovCommonOperationFactory(),
            operationQueue: operationQueue
        )

        return GovernanceNotificationsInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            fetchOperationFactory: operationFactory,
            operationQueue: operationQueue
        )
    }
}
