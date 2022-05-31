import Foundation
import SoraFoundation

struct ParaStkYourCollatorsViewFactory {
    static func createView() -> ParaStkYourCollatorsViewProtocol? {
        let interactor = ParaStkYourCollatorsInteractor()
        let wireframe = ParaStkYourCollatorsWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = ParaStkYourCollatorsPresenter(interactor: interactor, wireframe: wireframe)

        let view = ParaStkYourCollatorsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
