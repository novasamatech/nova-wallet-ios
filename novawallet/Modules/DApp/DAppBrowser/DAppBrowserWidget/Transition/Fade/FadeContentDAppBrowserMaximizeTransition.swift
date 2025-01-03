import Foundation
import UIKit
import SoraUI

struct FadeContentDAppBrowserMaximizeTransition {
    private let dependencies: FadeContentDAppBrowserTransitionDependencies

    init(dependencies: FadeContentDAppBrowserTransitionDependencies) {
        self.dependencies = dependencies
    }
}

// MARK: DAppBrowserWidgetTransitionProtocol

extension FadeContentDAppBrowserMaximizeTransition: DAppBrowserWidgetTransitionProtocol {
    func start() {
        guard let widgetView = dependencies.widgetViewClosure() else {
            return
        }

        let appearanceAnimator = dependencies.appearanceAnimator
        let disappearanceAnimator = dependencies.disappearanceAnimator

        let childNavigation = dependencies.childNavigation
        let layoutClosure = dependencies.layoutDependencies.layoutClosure
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure

        disappearanceAnimator.animate(
            view: widgetView.contentContainerView
        ) { _ in
            childNavigation {
                guard let browserView = dependencies.browserViewClosure() else {
                    return
                }

                let containerView = layoutClosure()

                UIView.animate(
                    withDuration: 0.25
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
}
