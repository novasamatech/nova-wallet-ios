import UIKit

final class CardPresentingAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let duration: TimeInterval
    let initialFrame: CGRect
    let finalFrame: CGRect
    let presenterCornerRadius: CGFloat
    let presentedCornerRadius: CGFloat

    init(
        duration: TimeInterval,
        initialFrame: CGRect,
        finalFrame: CGRect,
        presenterCornerRadius: CGFloat = 0,
        presentedCornerRadius: CGFloat = 0
    ) {
        self.duration = duration
        self.initialFrame = initialFrame
        self.finalFrame = finalFrame
        self.presenterCornerRadius = presenterCornerRadius
        self.presentedCornerRadius = presentedCornerRadius

        super.init()
    }

    override init() {
        fatalError("Use `init(duration: , initialFrame:, finalFrame: , cornerRadius:)` instead")
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

        fromVC.view.layer.masksToBounds = true

        toVC.view.layer.masksToBounds = true
        toVC.view.frame = initialFrame

        let wdiff: CGFloat = UIConstants.horizontalInset * 2
        let hdiff: CGFloat = fromVC.view.safeAreaInsets.top * 2
        let scaleX = (fromVC.view.bounds.width - wdiff) / fromVC.view.bounds.width
        let heightDiffAfterScale = (fromVC.view.bounds.height - (fromVC.view.bounds.height * scaleX)) / 2

        let yOffset = (fromVC.view.safeAreaInsets.top - heightDiffAfterScale) + 10

        transitionContext.containerView.addSubview(toVC.view)
        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.4,
            options: .curveEaseIn,
            animations: {
                toVC.view.transform = CGAffineTransform(
                    translationX: 0,
                    y: self.finalFrame.minY
                )
                toVC.view.frame = self.finalFrame
                toVC.view.layer.cornerRadius = self.presenterCornerRadius

                fromVC.view.layer.cornerRadius = self.presentedCornerRadius
                var transform = CATransform3DIdentity
                transform = CATransform3DScale(transform, scaleX, scaleX, 1.0)
                transform = CATransform3DTranslate(transform, .zero, yOffset, .zero)
                fromVC.view.layer.transform = transform
                fromVC.view.alpha = 0.6
            }
        ) { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
