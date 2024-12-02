import Foundation
import SoraFoundation

struct DAppBrowserTabListViewFactory {
    static func createView() -> DAppBrowserTabListViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let tabManager = DAppBrowserTabManager.shared

        let interactor = DAppBrowserTabListInteractor(
            tabManager: tabManager,
            operationQueue: operationQueue
        )
        let wireframe = DAppBrowserTabListWireframe()

        let localizationManager = LocalizationManager.shared

        let imageViewModelFactory = WebViewRenderImageViewModelFactory(
            fileRepository: FileRepository(),
            renderFetchOperationQueue: operationQueue
        )
        let viewModelFactory = DAppBrowserTabListViewModelFactory(imageViewModelFactory: imageViewModelFactory)

        let presenter = DAppBrowserTabListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
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
