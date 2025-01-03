import Foundation
import UIKit

typealias DAppBrowserChildNavigationClosure = ((_ completion: @escaping () -> Void) -> Void)

enum DAppBrowserWidgetTransitionBuilderError: Error {
    case missingRequiredDependencies
    case wrongLayoutState
}

class DAppBrowserWidgetTransitionBuilder {
    private var browserViewClosure: (() -> UIView?)?
    private var widgetViewClosure: (() -> DAppBrowserWidgetView?)?

    private var childNavigation: DAppBrowserChildNavigationClosure?
    private var layoutDependencies: DAppBrowserLayoutTransitionDependencies?

    init(
        browserViewClosure: (() -> UIView?)? = nil,
        widgetViewClosure: (() -> DAppBrowserWidgetView?)? = nil,
        childNavigation: DAppBrowserChildNavigationClosure? = nil,
        layoutDependencies: DAppBrowserLayoutTransitionDependencies? = nil
    ) {
        self.browserViewClosure = browserViewClosure
        self.widgetViewClosure = widgetViewClosure
        self.childNavigation = childNavigation
        self.layoutDependencies = layoutDependencies
    }
}

// MARK: Private

private extension DAppBrowserWidgetTransitionBuilder {
    func buildDisappearTransition() throws -> DAppBrowserWidgetTransitionProtocol {
        guard let layoutDependencies else {
            throw DAppBrowserWidgetTransitionBuilderError.missingRequiredDependencies
        }

        return DAppBrowserCloseTransition(
            dependencies: layoutDependencies
        )
    }

    func buildAppearedTransition(
        for state: DAppBrowserWidgetLayout
    ) throws -> DAppBrowserWidgetTransitionProtocol {
        guard
            let browserViewClosure,
            let widgetViewClosure,
            let childNavigation,
            let layoutDependencies
        else {
            throw DAppBrowserWidgetTransitionBuilderError.missingRequiredDependencies
        }

        let dependencies = FadeContentDAppBrowserTransitionDependencies(
            browserViewClosure: browserViewClosure,
            widgetViewClosure: widgetViewClosure,
            childNavigation: childNavigation,
            layoutDependencies: layoutDependencies
        )

        return switch state {
        case .maximized:
            FadeContentDAppBrowserMaximizeTransition(
                dependencies: dependencies
            )
        case .minimized:
            FadeContentDAppBrowserMinimizeTransition(
                dependencies: dependencies
            )
        default:
            throw DAppBrowserWidgetTransitionBuilderError.wrongLayoutState
        }
    }
}

// MARK: Internal

extension DAppBrowserWidgetTransitionBuilder {
    @discardableResult
    func setBrowserView(_ closure: @escaping () -> UIView?) -> Self {
        browserViewClosure = closure

        return self
    }

    @discardableResult
    func setWidgetContentView(_ closure: @escaping () -> DAppBrowserWidgetView?) -> Self {
        widgetViewClosure = closure

        return self
    }

    @discardableResult
    func setChildNavigation(_ closure: DAppBrowserChildNavigationClosure?) -> Self {
        childNavigation = closure

        return self
    }

    @discardableResult
    func setWidgetLayout(_ dependencies: DAppBrowserLayoutTransitionDependencies?) -> Self {
        layoutDependencies = dependencies

        return self
    }

    func build(for layoutState: DAppBrowserWidgetLayout) throws -> DAppBrowserWidgetTransitionProtocol {
        switch layoutState {
        case .maximized, .minimized:
            try buildAppearedTransition(for: layoutState)
        case .closed:
            try buildDisappearTransition()
        }
    }
}
