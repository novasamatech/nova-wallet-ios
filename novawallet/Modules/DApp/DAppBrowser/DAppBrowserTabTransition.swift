import Foundation
import UIKit

enum DAppBrowserTabTransition {
    static func setTransition(
        from sourceController: UIViewController?,
        to destController: UIViewController?,
        tabId: UUID?
    ) {
        if #available(iOS 18.0, *) {
            guard let tabId else { return }

            let options = UIViewController.Transition.ZoomOptions()
            options.interactiveDismissShouldBegin = { context in
                guard let destinationController = destController as? DAppBrowserViewController else {
                    return true
                }

                let shouldDismiss = atViewEdge(
                    context.location,
                    view: destinationController.view
                )

                let canBeDismissedInteractively: Bool = destinationController.canBeDismissedInteractively()
                let willDismiss = shouldDismiss && canBeDismissedInteractively

                if willDismiss {
                    destinationController.willBeDismissedInteractively()
                }

                return willDismiss
            }

            options.alignmentRectProvider = { context in
                guard let destinationController = context.zoomedViewController as? DAppBrowserViewController else {
                    return .zero
                }
                let container = destinationController.rootView.webViewContainer

                return container.convert(container.bounds, to: destinationController.rootView)
            }

            destController?.preferredTransition = .zoom(options: options) { context in
                let source = context.sourceViewController as? DAppBrowserTabViewTransitionProtocol
                let destintation = context.zoomedViewController as? DAppBrowserTransitionProtocol

                let destinationTabId = destintation?.idForTransitioningTab() ?? tabId

                return source?.getTabViewForTransition(for: destinationTabId)
            }
        } else {
            let transition = CATransition()
            transition.duration = 0.25
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            transition.type = .fade

            sourceController?.navigationController?.view.layer.add(transition, forKey: nil)
        }
    }

    static var animated: Bool {
        if #available(iOS 18.0, *) {
            true
        } else {
            false
        }
    }

    static func atViewEdge(
        _ point: CGPoint,
        view: UIView,
        edgeWidth: CGFloat = 20
    ) -> Bool {
        let atLeftEdge = point.x <= edgeWidth
        let atRightEdge = point.x >= view.bounds.width - edgeWidth

        return atLeftEdge || atRightEdge
    }
}
