import Foundation
import SoraFoundation

struct GovernanceNotificationsViewFactory {
    static func createView(
        settings: GovernanceNotificationsInitModel?,
        completion: @escaping ([ChainModel.Id: GovernanceNotificationsModel]) -> Void
    ) -> GovernanceNotificationsViewProtocol? {
        let interactor = GovernanceNotificationsInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry)
        let wireframe = GovernanceNotificationsWireframe(completion: completion)

        let presenter = GovernanceNotificationsPresenter(
            initState: settings,
            interactor: interactor,
            wireframe: wireframe
        )

        let view = GovernanceNotificationsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
