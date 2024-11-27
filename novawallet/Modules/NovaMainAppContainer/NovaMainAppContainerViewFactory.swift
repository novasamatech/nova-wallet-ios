import Foundation
import UIKit

struct NovaMainAppContainerViewFactory {
    static func createView(
        tabBarController: UIViewController,
        browserWidgetController: NovaMainContainerDAppBrowserProtocol
    ) -> NovaMainAppContainerViewProtocol? {
        let interactor = NovaMainAppContainerInteractor()
        let wireframe = NovaMainAppContainerWireframe()

        let presenter = NovaMainAppContainerPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        let view = NovaMainAppContainerViewController(
            presenter: presenter,
            tabController: tabBarController,
            browserWidgetController: browserWidgetController
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
