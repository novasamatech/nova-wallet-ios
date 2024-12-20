import SoraUI

struct DAppBrowserLayoutTransitionDependencies {
    let layoutClosure: () -> (UIView?)
    let animatableClosure: (() -> Void)?
    let transformClosure: (() -> Void)?

    init(
        layoutClosure: @escaping () -> UIView?,
        animatableClosure: (() -> Void)? = nil,
        transformClosure: (() -> Void)? = nil
    ) {
        self.layoutClosure = layoutClosure
        self.animatableClosure = animatableClosure
        self.transformClosure = transformClosure
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
        duration: 0.1
    )
    let blockAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.25,
        delay: 0,
        options: [.curveEaseOut]
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
