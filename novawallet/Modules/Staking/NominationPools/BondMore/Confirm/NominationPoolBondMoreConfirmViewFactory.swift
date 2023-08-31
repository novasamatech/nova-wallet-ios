import Foundation
import SoraFoundation

struct NominationPoolBondMoreConfirmViewFactory {
    static func createView() -> NominationPoolBondMoreConfirmViewProtocol? {
        let interactor = NominationPoolBondMoreConfirmInteractor()
        let wireframe = NominationPoolBondMoreConfirmWireframe()

        let presenter = NominationPoolBondMoreConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = NominationPoolBondMoreConfirmViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
