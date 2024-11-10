import Foundation

struct DAppBrowserTabsViewFactory {
    static func createView(selectClosure: @escaping (UUID) -> Void) -> DAppBrowserTabsViewProtocol? {
        let interactor = DAppBrowserTabsInteractor(tabManager: DAppBrowserTabsManager.shared)
        let wireframe = DAppBrowserTabsWireframe()

        let presenter = DAppBrowserTabsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectClosure: selectClosure
        )

        let view = DAppBrowserTabsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
