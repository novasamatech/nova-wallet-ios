import UIKit

final class CardDismissingAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration: TimeInterval
    let finalFrame: CGRect
    let presenterCornerRadius: CGFloat
    let presentedCornerRadius: CGFloat

    init(
        duration: TimeInterval,
        finalFrame: CGRect,
        presenterCornerRadius: CGFloat = 0,
        presentedCornerRadius: CGFloat = 0
    ) {
        self.duration = duration
        self.finalFrame = finalFrame
        self.presenterCornerRadius = presenterCornerRadius
        self.presentedCornerRadius = presentedCornerRadius

        super.init()
    }

    override init() {
        fatalError("Use `init(duration:, initialFrame:, finalFrame: , cornerRadius:)` instead")
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let fromVC = transitionContext.viewController(
                forKey: UITransitionContextViewControllerKey.from
            ),
            let toVC = transitionContext.viewController(
                forKey: UITransitionContextViewControllerKey.to
            )
        else { return }

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            animations: {
                toVC.view.transform3D = CATransform3DIdentity
                toVC.view.layer.cornerRadius = 0
                toVC.view.layer.masksToBounds = true
                toVC.view.alpha = 1

                fromVC.view.frame = self.finalFrame
            },
            completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }
}
