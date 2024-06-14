import Foundation
import SoraFoundation

struct NetworkAddNodeViewFactory {
    static func createView() -> NetworkAddNodeViewProtocol? {
        let interactor = NetworkAddNodeInteractor()
        let wireframe = NetworkAddNodeWireframe()

        let presenter = NetworkAddNodePresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared
        )

        let view = NetworkAddNodeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
