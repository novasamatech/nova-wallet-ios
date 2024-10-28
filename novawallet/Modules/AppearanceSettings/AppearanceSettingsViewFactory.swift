import Foundation
import SoraKeystore
import SoraFoundation

struct AppearanceSettingsViewFactory {
    static func createView() -> AppearanceSettingsViewProtocol? {
        let settingsManager = SettingsManager.shared
        let eventCenter = EventCenter.shared

        let interactor = AppearanceSettingsInteractor(
            settingsManager: settingsManager,
            eventCenter: eventCenter
        )

        let wireframe = AppearanceSettingsWireframe()

        let presenter = AppearanceSettingsPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = AppearanceSettingsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
