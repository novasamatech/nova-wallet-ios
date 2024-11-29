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

        dependencies.disappearanceAnimator.animate(
            view: browserView
        ) { _ in
            dependencies.layout {
                guard let widgetView = dependencies.widgetViewClosure() else {
                    return
                }

                dependencies.appearanceAnimator.animate(
                    view: widgetView.contentContainerView,
                    completionBlock: nil
                )
            }

            dependencies.childNavigation {}
        }
    }
}
