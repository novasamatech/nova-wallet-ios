import Foundation

struct DAppBrowserTabListViewFactory {
    static func createView() -> DAppBrowserTabListViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = DAppBrowserTabListInteractor(
            tabManager: DAppBrowserTabManager.shared,
            operationQueue: operationQueue
        )
        let wireframe = DAppBrowserTabListWireframe()

        let presenter = DAppBrowserTabListPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = DAppBrowserTabListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
