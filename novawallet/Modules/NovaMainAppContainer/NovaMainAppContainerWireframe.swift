import Foundation

final class NovaMainAppContainerWireframe: NovaMainAppContainerWireframeProtocol {
    private let tabBar: MainTabBarViewProtocol
    private let browserWidget: DAppBrowserWidgetViewProtocol

    init(
        tabBar: MainTabBarViewProtocol,
        browserWidget: DAppBrowserWidgetViewProtocol
    ) {
        self.tabBar = tabBar
        self.browserWidget = browserWidget
    }

    func showChildViews(on view: ControllerBackedProtocol?) {
        guard
            let controller = view?.controller as? NovaMainAppContainerViewController,
            let browserWidgetView = browserWidget.controller.view,
            let tabBarView = tabBar.controller.view
        else {
            return
        }

        controller.addChild(browserWidget.controller)
        controller.view.addSubview(browserWidgetView)

        controller.addChild(tabBar.controller)
        controller.view.addSubview(tabBarView)

        controller.setupLayout(
            bottomView: browserWidgetView,
            topView: tabBarView
        )

        browserWidget.controller.didMove(toParent: controller)
        tabBar.controller.didMove(toParent: controller)
    }
}
