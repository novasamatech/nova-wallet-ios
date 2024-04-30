import Foundation
import SoraFoundation

struct ImportCloudPasswordViewFactory {
    static func createView() -> ImportCloudPasswordViewProtocol? {
        let interactor = ImportCloudPasswordInteractor()
        let wireframe = ImportCloudPasswordWireframe()

        let presenter = ImportCloudPasswordPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = ImportCloudPasswordViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
