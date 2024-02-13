import Foundation
import SoraFoundation

struct NotificationsManagementViewFactory {
    static func createView() -> NotificationsManagementViewProtocol? {
        let interactor = NotificationsManagementInteractor()
        let wireframe = NotificationsManagementWireframe()

        let viewModelFactory = NotificationsManagemenViewModelFactory(
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = NotificationsManagementPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )

        let view = NotificationsManagementViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
