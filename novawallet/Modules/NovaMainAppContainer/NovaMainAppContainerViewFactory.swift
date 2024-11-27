import Foundation
import UIKit

struct NovaMainAppContainerViewFactory {
    static func createView(
        tabBarController: UIViewController,
        browserWidgetController: NovaMainContainerDAppBrowserProtocol
    ) -> NovaMainAppContainerViewProtocol? {
        let wireframe = NovaMainAppContainerWireframe()

        let presenter = NovaMainAppContainerPresenter(wireframe: wireframe)

        let view = NovaMainAppContainerViewController(
            presenter: presenter,
            tabController: tabBarController,
            browserWidgetController: browserWidgetController
        )

        presenter.view = view

        return view
    }
}
