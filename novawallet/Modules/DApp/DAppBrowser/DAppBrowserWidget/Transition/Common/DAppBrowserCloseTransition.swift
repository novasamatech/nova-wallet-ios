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

        UIView.animate(withDuration: 0.2) {
            containerView?.layoutIfNeeded()
            dependencies.animatableClosure?()
        }
    }
}