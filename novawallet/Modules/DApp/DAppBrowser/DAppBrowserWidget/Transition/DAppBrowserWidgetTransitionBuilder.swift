import Foundation
import UIKit

typealias DAppBrowserTransitionStep = ((_ completion: @escaping () -> Void) -> Void)

enum DAppBrowserWidgetTransitionDestinationState {
    case maximized
    case minimized
}

class DAppBrowserWidgetTransitionBuilder {
    private var browserViewClosure: (() -> UIView?)?
    private var widgetViewClosure: (() -> DAppBrowserWidgetView?)?

    private var childNavigation: DAppBrowserTransitionStep?
    private var layout: DAppBrowserTransitionStep?

    init(
        browserViewClosure: (() -> UIView?)? = nil,
        widgetViewClosure: (() -> DAppBrowserWidgetView?)? = nil,
        childNavigation: DAppBrowserTransitionStep? = nil,
        layout: DAppBrowserTransitionStep? = nil
    ) {
        self.browserViewClosure = browserViewClosure
        self.widgetViewClosure = widgetViewClosure
        self.childNavigation = childNavigation
        self.layout = layout
    }

    @discardableResult
    func addingBrowserView(_ closure: @escaping () -> UIView?) -> Self {
        browserViewClosure = closure

        return self
    }

    @discardableResult
    func addingWidgetContentView(_ closure: @escaping () -> DAppBrowserWidgetView?) -> Self {
        widgetViewClosure = closure

        return self
    }

    @discardableResult
    func addingChildNavigation(_ closure: DAppBrowserTransitionStep?) -> Self {
        childNavigation = closure

        return self
    }

    @discardableResult
    func addingWidgetLayoutClosure(_ closure: DAppBrowserTransitionStep?) -> Self {
        layout = closure

        return self
    }

    func build(for layoutState: DAppBrowserWidgetLayout) throws -> DAppBrowserTransitionProtocol {
        guard
            let browserViewClosure,
            let widgetViewClosure,
            let childNavigation,
            let layout
        else {
            throw NSError()
        }

        let dependencies = FadeContentDAppBrowserTransitionDependencies(
            browserViewClosure: browserViewClosure,
            widgetViewClosure: widgetViewClosure,
            childNavigation: childNavigation,
            layout: layout
        )

        return switch layoutState {
        case .maximized:
            FadeContentDAppBrowserMaximizeTransition(
                dependencies: dependencies
            )
        case .minimized, .closed:
            FadeContentDAppBrowserMinimizeTransition(
                dependencies: dependencies
            )
        }
    }
}
