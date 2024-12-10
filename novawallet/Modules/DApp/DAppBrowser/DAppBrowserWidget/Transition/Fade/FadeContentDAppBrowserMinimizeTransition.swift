import Foundation
import UIKit

struct FadeContentDAppBrowserMinimizeTransition {
    private let dependencies: FadeContentDAppBrowserTransitionDependencies

    init(dependencies: FadeContentDAppBrowserTransitionDependencies) {
        self.dependencies = dependencies
    }
}

// MARK: DAppBrowserTransitionProtocol

extension FadeContentDAppBrowserMinimizeTransition: DAppBrowserTransitionProtocol {
    func start() {
        guard let browserView = dependencies.browserViewClosure() else {
            return
        }

        let appearanceAnimator = dependencies.appearanceAnimator
        let disappearanceAnimator = dependencies.disappearanceAnimator

        let childNavigation = dependencies.childNavigation
        let layoutClosure = dependencies.layoutDependencies.layoutClosure
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure

        let containerView = layoutClosure()

        disappearanceAnimator.animate(view: browserView) { _ in
            childNavigation {}
        }

        UIView.animate(withDuration: 0.25) {
            layoutAnimatables?()
            containerView?.layoutIfNeeded()
        } completion: { _ in
            guard let widgetView = dependencies.widgetViewClosure() else {
                return
            }

            appearanceAnimator.animate(
                view: widgetView.contentContainerView,
                completionBlock: nil
            )
        }
    }

    func start(with completion: @escaping () -> Void) {
        guard let browserView = dependencies.browserViewClosure() else {
            return
        }

        let appearanceAnimator = dependencies.appearanceAnimator
        let disappearanceAnimator = dependencies.disappearanceAnimator

        let childNavigation = dependencies.childNavigation
        let layoutClosure = dependencies.layoutDependencies.layoutClosure
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure

        let containerView = layoutClosure()

        disappearanceAnimator.animate(view: browserView) { _ in
            childNavigation {}
        }

        UIView.animate(withDuration: 0.25) {
            layoutAnimatables?()
            containerView?.layoutIfNeeded()
        } completion: { _ in
            guard let widgetView = dependencies.widgetViewClosure() else {
                return
            }

            appearanceAnimator.animate(view: widgetView.contentContainerView) { _ in
                completion()
            }
        }
    }
}
