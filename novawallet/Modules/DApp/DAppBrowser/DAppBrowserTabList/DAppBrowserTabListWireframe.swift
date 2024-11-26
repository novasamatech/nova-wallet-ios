import Foundation
import UIKit

final class DAppBrowserTabListWireframe: DAppBrowserTabListWireframeProtocol {
    func showTab(
        from view: DAppBrowserTabListViewProtocol?,
        _ tab: DAppBrowserTab
    ) {
        guard let browserView = DAppBrowserViewFactory.createView(selectedTab: tab) else {
            return
        }

        if #available(iOS 18.0, *) {
            let options = UIViewController.Transition.ZoomOptions()
            options.alignmentRectProvider = { context in
                guard let destinationController = context.zoomedViewController as? DAppBrowserViewController else {
                    return .zero
                }
                let container = destinationController.rootView.webViewContainer

                return container.convert(container.bounds, to: destinationController.rootView)
            }

            browserView.controller.preferredTransition = .zoom(options: options) { _ in
                view?.getTabViewForTransition(for: tab.uuid)
            }
        } else {
            // Fallback on earlier versions
        }

        view?.controller.navigationController?.pushViewController(
            browserView.controller,
            animated: true
        )
    }

    func close(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(animated: true)
    }
}
