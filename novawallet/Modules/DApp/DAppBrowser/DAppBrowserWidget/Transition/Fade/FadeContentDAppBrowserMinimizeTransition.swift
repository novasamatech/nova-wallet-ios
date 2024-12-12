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
        guard let browserView = dependencies.browserViewClosure() else {
            return
        }

        let appearanceAnimator = dependencies.appearanceAnimator
        let disappearanceAnimator = dependencies.disappearanceAnimator
        let blockAnimator = dependencies.blockAnimator

        let childNavigation = dependencies.childNavigation
        let layoutClosure = dependencies.layoutDependencies.layoutClosure
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure

        let containerView = layoutClosure()

        disappearanceAnimator.animate(view: browserView) { _ in
            childNavigation {}
        }

        
        blockAnimator.animate {
            layoutAnimatables?()
            containerView?.layoutIfNeeded()
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
