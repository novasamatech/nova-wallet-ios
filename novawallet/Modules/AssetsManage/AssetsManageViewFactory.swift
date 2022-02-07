import Foundation
import SoraFoundation
import SoraKeystore

struct AssetsManageViewFactory {
    static func createView() -> AssetsManageViewProtocol? {
        let interactor = AssetsManageInteractor(
            settingsManager: SettingsManager.shared,
            eventCenter: EventCenter.shared
        )

        let wireframe = AssetsManageWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = AssetsManagePresenter(interactor: interactor, wireframe: wireframe)

        let view = AssetsManageViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
