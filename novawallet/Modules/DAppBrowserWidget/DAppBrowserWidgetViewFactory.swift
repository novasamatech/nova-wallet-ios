import Foundation
import SoraFoundation

struct DAppBrowserWidgetViewFactory {
    static func createView() -> DAppBrowserWidgetContainableView? {
        let interactor = DAppBrowserWidgetInteractor(
            tabManager: DAppBrowserTabManager.shared
        )

        let presenter = DAppBrowserWidgetPresenter(
            interactor: interactor,
            browserTabsViewModelFactory: DAppBrowserWidgetViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        let view = DAppBrowserWidgetViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
