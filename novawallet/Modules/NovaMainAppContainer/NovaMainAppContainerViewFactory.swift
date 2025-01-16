import Foundation
import UIKit

struct NovaMainAppContainerViewFactory {
    static func createView(
        tabBarController: MainTabBarViewController,
        browserWidgetController: DAppBrowserWidgetViewController
    ) -> NovaMainAppContainerViewProtocol? {
        let wireframe = NovaMainAppContainerWireframe(
            tabBar: tabBarController,
            browserWidget: browserWidgetController
        )

        let presenter = NovaMainAppContainerPresenter(wireframe: wireframe)

        let view = NovaMainAppContainerViewController(
            presenter: presenter,
            logger: Logger.shared
        )

        view.tabBar = tabBarController
        view.browserWidget = browserWidgetController

        presenter.view = view

        return view
    }
}
