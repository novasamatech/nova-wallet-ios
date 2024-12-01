import Foundation
import UIKit

enum DAppBrowserFactory {
    static func createFullBrowser(with tab: DAppBrowserTab) -> UIViewController? {
        guard
            let tabsView = DAppBrowserTabListViewFactory.createView(),
            let browserView = DAppBrowserViewFactory.createView(selectedTab: tab)
        else {
            return nil
        }

        return createFullBrowser(
            with: tab.uuid,
            tabsView,
            browserView
        )
    }

    static func createChildFullBrowser(
        with tab: DAppBrowserTab,
        parent: DAppBrowserParentViewProtocol
    ) -> UIViewController? {
        guard
            let tabsView = DAppBrowserTabListViewFactory.createChildView(for: parent),
            let browserView = DAppBrowserViewFactory.createChildView(
                for: parent,
                selectedTab: tab
            )
        else {
            return nil
        }

        return createFullBrowser(
            with: tab.uuid,
            tabsView,
            browserView
        )
    }

    static func createBrowserTabsView() -> UIViewController? {
        guard let tabsView = DAppBrowserTabListViewFactory.createView() else {
            return nil
        }

        let navigationController = NovaNavigationController(rootViewController: tabsView.controller)
        navigationController.barSettings = .defaultSettings.bySettingCloseButton(false)

        navigationController.modalPresentationStyle = .overFullScreen

        return navigationController
    }

    static func createChildBrowserTabsView(parent: DAppBrowserParentViewProtocol) -> UIViewController? {
        guard let tabsView = DAppBrowserTabListViewFactory.createChildView(for: parent) else {
            return nil
        }

        let navigationController = NovaNavigationController(rootViewController: tabsView.controller)
        navigationController.barSettings = .defaultSettings.bySettingCloseButton(false)

        navigationController.modalPresentationStyle = .overFullScreen

        return navigationController
    }

    private static func createFullBrowser(
        with tabId: UUID,
        _ tabsView: DAppBrowserTabListViewProtocol,
        _ browserView: DAppBrowserViewProtocol
    ) -> UIViewController? {
        tabsView.controller.hidesBottomBarWhenPushed = true
        browserView.controller.hidesBottomBarWhenPushed = true

        DAppBrowserTabTransition.setTransition(
            from: tabsView.controller,
            to: browserView.controller,
            tabId: tabId
        )

        tabsView.controller.loadViewIfNeeded()

        let controllers = [tabsView.controller, browserView.controller]

        let navigationController = NovaNavigationController()
        navigationController.barSettings = .defaultSettings.bySettingCloseButton(false)

        navigationController.setViewControllers(
            controllers,
            animated: false
        )

        navigationController.modalPresentationStyle = .overFullScreen

        return navigationController
    }
}
