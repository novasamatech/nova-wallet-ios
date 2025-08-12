import Foundation
import Foundation_iOS

final class MultisigNotificationsViewFactory {
    static func createView(
        with settings: MultisigNotificationsModel,
        completion: @escaping (MultisigNotificationsModel) -> Void
    ) -> ControllerBackedProtocol? {
        let wireframe = MultisigNotificationsWireframe(completion: completion)

        let presenter = MultisigNotificationsPresenter(
            wireframe: wireframe,
            settings: settings,
            localizationManager: LocalizationManager.shared
        )

        let view = MultisigNotificationsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
