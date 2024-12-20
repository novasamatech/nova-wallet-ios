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
        view?.controller.children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }
    }
}
