import Foundation
import SoraKeystore
import SoraFoundation

struct AppearanceSettingsViewFactory {
    static func createView() -> AppearanceSettingsViewProtocol? {
        let settingsManager = SettingsManager.shared
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
