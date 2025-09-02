import Foundation
import Foundation_iOS

struct DAppBrowserTabListViewFactory {
    static func createView() -> DAppBrowserTabListViewProtocol? {
        let wireframe = DAppBrowserTabListWireframe()

        return createView(with: wireframe)
    }

    static func createChildView(
        for parent: DAppBrowserParentViewProtocol
    ) -> DAppBrowserTabListViewProtocol? {
        let wireframe = DAppBrowserTabListChildViewWireframe(parentView: parent)

        return createView(with: wireframe)
    }

    private static func createView(
        with wireframe: DAppBrowserTabListWireframeProtocol
    ) -> DAppBrowserTabListViewProtocol? {
        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let tabManager = DAppBrowserTabManager.shared

        let interactor = DAppBrowserTabListInteractor(
            tabManager: tabManager,
            operationQueue: operationQueue
        )

        let localizationManager = LocalizationManager.shared

        let dappIconViewModelFactory = DAppIconViewModelFactory()
        let imageViewModelFactory = WebViewRenderImageViewModelFactory(
            fileRepository: FileRepository(),
            renderFetchOperationQueue: operationQueue
        )
        let viewModelFactory = DAppBrowserTabListViewModelFactory(
            imageViewModelFactory: imageViewModelFactory,
            dAppIconViewModelFactory: dappIconViewModelFactory
        )

        let wallet: MetaAccountModel = SelectedWalletSettings.shared.value

        let presenter = DAppBrowserTabListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            metaId: wallet.metaId,
            localizationManager: localizationManager
        )

        let webViewPool = WebViewPool.shared

        let view = DAppBrowserTabListViewController(
            presenter: presenter,
            webViewPoolEraser: webViewPool,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
