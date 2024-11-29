import SoraUI

struct FadeContentDAppBrowserTransitionDependencies {
    let browserViewClosure: () -> UIView?
    let widgetViewClosure: () -> DAppBrowserWidgetView?

    let childNavigation: DAppBrowserTransitionStep
    let layout: DAppBrowserTransitionStep

    let appearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0
    )
    let disappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: 0.2
    )

    init(
        browserViewClosure: @escaping () -> UIView?,
        widgetViewClosure: @escaping () -> DAppBrowserWidgetView?,
        childNavigation: @escaping DAppBrowserTransitionStep,
        layout: @escaping DAppBrowserTransitionStep
    ) {
        self.browserViewClosure = browserViewClosure
        self.widgetViewClosure = widgetViewClosure
        self.childNavigation = childNavigation
        self.layout = layout
    }
}
