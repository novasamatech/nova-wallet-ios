import Foundation
import UIKit

struct DAppBrowserCloseTransition {
    private let dependencies: FadeContentDAppBrowserTransitionDependencies

    init(dependencies: FadeContentDAppBrowserTransitionDependencies) {
        self.dependencies = dependencies
    }
}

// MARK: DAppBrowserWidgetTransitionProtocol

extension DAppBrowserCloseTransition: DAppBrowserWidgetTransitionProtocol {
    func start() {
        let containerView = dependencies.layoutDependencies.layoutClosure()
        let layoutAnimatables = dependencies.layoutDependencies.animatableClosure
        let childNavigationClosure = dependencies.childNavigation

        dependencies.blockAnimator.animate {
            containerView?.layoutIfNeeded()

            layoutAnimatables?()
        } completionBlock: { _ in
            childNavigationClosure?() {}
        }
    }
}
