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

        let childNavigation = dependencies.childNavigation
        let layoutClosure = dependencies.layoutDependencies.layoutClosure
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure
        let transformClosure = dependencies.layoutDependencies.transformClosure

        let containerView = layoutClosure()

        if let browserView = dependencies.browserViewClosure?() {
            disappearanceAnimator.animate(view: browserView) { _ in
                childNavigation?() {}
            }
        } else {
            childNavigation?() {}
        }

        let widgetView = dependencies.widgetViewClosure?()
        widgetView?.contentContainerView.alpha = 0

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.4,
            options: .curveEaseIn
        ) {
            layoutAnimatables?()
            containerView?.layoutIfNeeded()

            UIView.performWithoutAnimation {
                transformClosure?()
            }
        } completion: { _ in
            guard let widgetView = dependencies.widgetViewClosure?() else {
                return
            }

            appearanceAnimator.animate(
                view: widgetView.contentContainerView,
                completionBlock: nil
            )
        }
    }
}
