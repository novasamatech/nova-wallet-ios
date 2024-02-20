import Foundation
import SoraFoundation

struct GovernanceNotificationsViewFactory {
    static func createView(
        settings _: [ChainModel.Id: GovernanceNotificationsModel],
        completion: @escaping ([ChainModel.Id: GovernanceNotificationsModel]) -> Void
    ) -> GovernanceNotificationsViewProtocol? {
        let interactor = GovernanceNotificationsInteractor(chainRegistry: ChainRegistryFacade.sharedRegistry)
        let wireframe = GovernanceNotificationsWireframe(completion: completion)

        let presenter = GovernanceNotificationsPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = GovernanceNotificationsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared,
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
