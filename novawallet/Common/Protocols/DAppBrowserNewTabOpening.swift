import Foundation
import UIKit

protocol DAppBrowserNewTabOpening: AnyObject {
    func showInExistingBrowserStack(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    )

    func showNewBrowserStack(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    )
}

extension DAppBrowserNewTabOpening {
    func showInExistingBrowserStack(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(selectedTab: tab) else {
            return
        }

        setTransition(
            for: browserView.controller,
            tabId: tab.uuid
        )

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: true
        )
    }

    func showNewBrowserStack(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    ) {
        guard
            let tabsView = DAppBrowserTabListViewFactory.createView(),
            let browserView = DAppBrowserViewFactory.createView(selectedTab: tab)
        else {
            return
        }

        tabsView.controller.hidesBottomBarWhenPushed = true
        browserView.controller.hidesBottomBarWhenPushed = true

        setTransition(
            for: browserView.controller,
            tabId: tab.uuid
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

        view?.controller.present(
            navigationController,
            animated: true
        )
    }
}

private extension DAppBrowserNewTabOpening {
    func setTransition(
        for controller: UIViewController,
        tabId: UUID
    ) {
        if #available(iOS 18.0, *) {
            let options = UIViewController.Transition.ZoomOptions()
            options.alignmentRectProvider = { context in
                guard let destinationController = context.zoomedViewController as? DAppBrowserViewController else {
                    return .zero
                }
                let container = destinationController.rootView.webViewContainer

                return container.convert(container.bounds, to: destinationController.rootView)
            }

            controller.preferredTransition = .zoom(options: options) { context in
                let source = context.sourceViewController as? DAppBrowserTabViewTransitionProtocol

                return source?.getTabViewForTransition(for: tabId)
            }
        } else {
            // Fallback on earlier versions
        }
    }
}
