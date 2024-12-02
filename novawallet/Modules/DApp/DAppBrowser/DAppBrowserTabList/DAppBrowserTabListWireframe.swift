import Foundation
import UIKit

final class DAppBrowserTabListWireframe: DAppBrowserTabListWireframeProtocol {
    func close(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(animated: true)
    }

    func showTab(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(selectedTab: tab) else {
            return
        }

        DAppBrowserTabTransition.setTransition(
            from: view?.controller,
            to: browserView.controller,
            tabId: tab.uuid
        )

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: DAppBrowserTabTransition.animated
        )
    }
}

final class DAppBrowserTabListChildViewWireframe: DAppBrowserTabListWireframeProtocol {
    private let parentView: DAppBrowserParentViewProtocol

    init(parentView: DAppBrowserParentViewProtocol) {
        self.parentView = parentView
    }

    func close(from _: ControllerBackedProtocol?) {
        parentView.close()
    }

    func showTab(
        _ tab: DAppBrowserTab,
        from view: ControllerBackedProtocol?
    ) {
        guard let browserView = DAppBrowserViewFactory.createChildView(
            for: parentView,
            selectedTab: tab
        ) else {
            return
        }

        DAppBrowserTabTransition.setTransition(
            from: view?.controller,
            to: browserView.controller,
            tabId: tab.uuid
        )

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: DAppBrowserTabTransition.animated
        )
    }
}
