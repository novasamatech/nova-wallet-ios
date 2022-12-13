import Foundation
import SoraFoundation
import SoraKeystore

struct AssetsSettingsViewFactory {
    static func createView() -> AssetsSettingsViewProtocol? {
        let interactor = AssetsSettingsInteractor(
            settingsManager: SettingsManager.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = AssetsSettingsWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = AssetsSettingsPresenter(interactor: interactor, wireframe: wireframe)

        let view = AssetsSettingsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
