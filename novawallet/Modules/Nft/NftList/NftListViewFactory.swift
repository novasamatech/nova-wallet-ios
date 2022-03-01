import Foundation
import SoraFoundation

struct NftListViewFactory {
    static func createView() -> NftListViewProtocol? {
        let interactor = NftListInteractor()
        let wireframe = NftListWireframe()

        let presenter = NftListPresenter(interactor: interactor, wireframe: wireframe)

        let localizationManager = LocalizationManager.shared

        let view = NftListViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
