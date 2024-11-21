import Foundation
import SoraFoundation

struct DAppBrowserTabListViewFactory {
    static func createView() -> DAppBrowserTabListViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = DAppBrowserTabListInteractor(
            tabManager: DAppBrowserTabManager.shared,
            operationQueue: operationQueue
        )
        let wireframe = DAppBrowserTabListWireframe()

        let localizationManager = LocalizationManager.shared

        let presenter = DAppBrowserTabListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: DAppBrowserTabListViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = DAppBrowserTabListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
