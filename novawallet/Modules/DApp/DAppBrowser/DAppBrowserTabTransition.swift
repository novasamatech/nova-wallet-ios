import Foundation
import UIKit

enum DAppBrowserTabTransition {
    static func setTransition(
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
