import SoraUI

struct DAppBrowserLayoutTransitionDependencies {
    let layoutClosure: () -> (UIView?)
    let animatableClosure: (() -> Void)?

    init(
        layoutClosure: @escaping () -> UIView?,
        animatableClosure: (() -> Void)? = nil
    ) {
        self.layoutClosure = layoutClosure
        self.animatableClosure = animatableClosure
    }
}

struct FadeContentDAppBrowserTransitionDependencies {
    let browserViewClosure: () -> UIView?
    let widgetViewClosure: () -> DAppBrowserWidgetView?

    let childNavigation: DAppBrowserChildNavigationClosure
    let layoutDependencies: DAppBrowserLayoutTransitionDependencies

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
        childNavigation: @escaping DAppBrowserChildNavigationClosure,
        layoutDependencies: DAppBrowserLayoutTransitionDependencies
    ) {
        self.browserViewClosure = browserViewClosure
        self.widgetViewClosure = widgetViewClosure
        self.childNavigation = childNavigation
        self.layoutDependencies = layoutDependencies
    }
}
