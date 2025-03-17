import Foundation
import UIKit

class DAppBrowserWidgetWireframe: NSObject, DAppBrowserWidgetWireframeProtocol {
    func showBrowser(
        from view: (any DAppBrowserParentWidgetViewProtocol)?,
        with tab: DAppBrowserTab?
    ) {
        guard let view else { return }

        let browserView: UIViewController? = if let tab {
            DAppBrowserFactory.createChildFullBrowser(
                with: tab,
                parent: view
            )
        } else {
            DAppBrowserFactory.createChildBrowserTabsView(parent: view)
        }

        guard let browserView else { return }

        browserView.view.alpha = 0

        view.controller.addChild(browserView)
        view.controller.view.addSubview(browserView.view)

        browserView.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        view.controller.view.layoutIfNeeded()

        browserView.didMove(toParent: view.controller)
    }

    func showMiniature(from view: (any DAppBrowserParentWidgetViewProtocol)?) {
        let childRemoveClosure: (UIViewController) -> Void = { child in
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
        }

        view?.controller.children.forEach { child in
            if let navigationController = child as? UINavigationController {
                navigationController.setViewControllers([], animated: false)
                childRemoveClosure(navigationController)
            } else {
                child.dismiss(animated: true) {
                    childRemoveClosure(child)
                }
            }
        }
    }
}
