import Foundation
import UIKit

struct FadeContentDAppBrowserMinimizeTransition {
    private let dependencies: FadeContentDAppBrowserTransitionDependencies

    init(dependencies: FadeContentDAppBrowserTransitionDependencies) {
        self.dependencies = dependencies
    }
}

// MARK: DAppBrowserWidgetTransitionProtocol

extension FadeContentDAppBrowserMinimizeTransition: DAppBrowserWidgetTransitionProtocol {
    func start() {
        let appearanceAnimator = dependencies.appearanceAnimator
        let disappearanceAnimator = dependencies.disappearanceAnimator
        let blockAnimator = dependencies.blockAnimator

        let childNavigation = dependencies.childNavigation
        let layoutClosure = dependencies.layoutDependencies.layoutClosure
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure
        let transformClosure = dependencies.layoutDependencies.transformClosure

        let containerView = layoutClosure()

        if let browserView = dependencies.browserViewClosure() {
            disappearanceAnimator.animate(view: browserView) { _ in
                childNavigation {}
            }
        } else {
            childNavigation {}
        }

        let widgetView = dependencies.widgetViewClosure()
        widgetView?.contentContainerView.alpha = 0

        blockAnimator.animate {
            layoutAnimatables?()
            containerView?.layoutIfNeeded()

            UIView.performWithoutAnimation {
                transformClosure?()
            }
        } completionBlock: { _ in
            guard let widgetView = dependencies.widgetViewClosure() else {
                return
            }

            appearanceAnimator.animate(
                view: widgetView.contentContainerView,
                completionBlock: nil
            )
        }
    }
}
