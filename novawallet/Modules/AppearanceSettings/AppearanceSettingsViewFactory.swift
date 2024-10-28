import Foundation
import SoraFoundation

struct AppearanceSettingsViewFactory {
    static func createView() -> AppearanceSettingsViewProtocol? {
        let interactor = AppearanceSettingsInteractor()
        let wireframe = AppearanceSettingsWireframe()

        let presenter = AppearanceSettingsPresenter(interactor: interactor, wireframe: wireframe)

        let view = AppearanceSettingsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
