import Foundation
import Keystore_iOS
import Foundation_iOS

struct AppearanceSettingsViewFactory {
    static func createView() -> AppearanceSettingsViewProtocol? {
        let appearanceFacade = AppearanceFacade.shared

        let wireframe = AppearanceSettingsWireframe()

        let presenter = AppearanceSettingsPresenter(
            appearanceFacade: appearanceFacade,
            wireframe: wireframe
        )

        let view = AppearanceSettingsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
