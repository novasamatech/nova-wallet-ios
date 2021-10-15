import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

struct NetworksViewFactory {
    static func createView() -> NetworksViewProtocol? {
        let wireframe = NetworksWireframe()
        let interactor = NetworksInteractor()

        let localizationManager = LocalizationManager.shared
        let presenter = NetworksPresenter(interactor: interactor, wireframe: wireframe)
        let view = NetworksViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter
        return view
    }
}
