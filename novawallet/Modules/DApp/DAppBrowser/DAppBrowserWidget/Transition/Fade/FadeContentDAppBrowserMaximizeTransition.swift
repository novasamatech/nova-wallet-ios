import Foundation
import UIKit
import UIKit_iOS

struct FadeContentDAppBrowserMaximizeTransition {
    private let dependencies: FadeContentDAppBrowserTransitionDependencies

    init(dependencies: FadeContentDAppBrowserTransitionDependencies) {
        self.dependencies = dependencies
    }
}

// MARK: DAppBrowserWidgetTransitionProtocol

extension FadeContentDAppBrowserMaximizeTransition: DAppBrowserWidgetTransitionProtocol {
    func start() {
        guard let widgetView = dependencies.widgetViewClosure?() else {
            return
        }

        let appearanceAnimator = dependencies.appearanceAnimator
        let disappearanceAnimator = dependencies.disappearanceAnimator

        let childNavigation = dependencies.childNavigation
        let layoutClosure = dependencies.layoutDependencies.layoutClosure
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure

        disappearanceAnimator.animate(
            view: widgetView.contentContainerView,
            completionBlock: nil
        )

        childNavigation?() {
            guard let browserView = dependencies.browserViewClosure?() else {
                return
            }

            let containerView = layoutClosure()

            UIView.animate(
                withDuration: 0.45,
                delay: 0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 0.4,
                options: .curveEaseIn
            ) {
                layoutAnimatables?()
                containerView?.layoutIfNeeded()
            }

            appearanceAnimator.animate(
                view: browserView,
                completionBlock: nil
            )
        }
    }
}
