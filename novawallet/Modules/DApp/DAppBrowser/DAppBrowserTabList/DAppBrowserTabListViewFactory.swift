import Foundation
import SoraFoundation

struct DAppBrowserTabListViewFactory {
    static func createView(dAppList: [DApp]) -> DAppBrowserTabListViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = DAppBrowserTabListInteractor(
            tabManager: DAppBrowserTabManager.shared,
            operationQueue: operationQueue
        )
        let wireframe = DAppBrowserTabListWireframe()

        let presenter = DAppBrowserTabListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            dAppList: dAppList
        )

        let view = DAppBrowserTabListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
