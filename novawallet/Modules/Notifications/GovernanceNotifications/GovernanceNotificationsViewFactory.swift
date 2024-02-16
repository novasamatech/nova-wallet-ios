import Foundation
import SoraFoundation

struct GovernanceNotificationsViewFactory {
    static func createView() -> GovernanceNotificationsViewProtocol? {
        let interactor = GovernanceNotificationsInteractor()
        let wireframe = GovernanceNotificationsWireframe()

        let presenter = GovernanceNotificationsPresenter(
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
