import Foundation
import UIKit
import SoraUI

struct FadeContentDAppBrowserMaximizeTransition {
    private let dependencies: FadeContentDAppBrowserTransitionDependencies

    init(dependencies: FadeContentDAppBrowserTransitionDependencies) {
        self.dependencies = dependencies
    }
}

// MARK: DAppBrowserTransitionProtocol

extension FadeContentDAppBrowserMaximizeTransition: DAppBrowserTransitionProtocol {
    func start() {
        guard let widgetView = dependencies.widgetViewClosure() else {
            return
        }

        dependencies.disappearanceAnimator.animate(
            view: widgetView.contentContainerView
        ) { _ in
            dependencies.childNavigation {
                guard let browserView = dependencies.browserViewClosure() else {
                    return
                }

                dependencies.layout {}

                dependencies.appearanceAnimator.animate(
                    view: browserView,
                    completionBlock: nil
                )
            }
        }
    }
}
