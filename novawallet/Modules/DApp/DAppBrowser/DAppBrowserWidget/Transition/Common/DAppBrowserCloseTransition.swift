import Foundation
import UIKit

struct DAppBrowserCloseTransition {
    private let dependencies: DAppBrowserLayoutTransitionDependencies

    init(dependencies: DAppBrowserLayoutTransitionDependencies) {
        self.dependencies = dependencies
    }
}

// MARK: DAppBrowserWidgetTransitionProtocol

extension DAppBrowserCloseTransition: DAppBrowserWidgetTransitionProtocol {
    func start() {
        let containerView = dependencies.layoutClosure()
        let layoutAnimatables = dependencies.animatableClosure
        let transformClosure = dependencies.transformClosure

        UIView.animate(withDuration: 0.2) {
            containerView?.layoutIfNeeded()

            UIView.performWithoutAnimation {
                transformClosure?()
            }

            layoutAnimatables?()
        }
    }
}
