import Foundation
import SoraFoundation

struct ParaStkSelectCollatorsViewFactory {
    static func createView(with _: ParachainStakingSharedState) -> ParaStkSelectCollatorsViewProtocol? {
        let interactor = ParaStkSelectCollatorsInteractor()
        let wireframe = ParaStkSelectCollatorsWireframe()

        let presenter = ParaStkSelectCollatorsPresenter(interactor: interactor, wireframe: wireframe)

        let localizationManager = LocalizationManager.shared

        let view = ParaStkSelectCollatorsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
