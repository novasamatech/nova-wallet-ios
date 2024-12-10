import UIKit
import SoraUI

final class CardPresentingTransition: NSObject {
    private let transitionDuration: TimeInterval

    init(transitionDuration: TimeInterval = 0.5) {
        self.transitionDuration = transitionDuration

        super.init()
    }
}

// MARK: Private

private extension CardPresentingTransition {
    func createSourceViewTransform(_ sourceView: UIView) -> CGAffineTransform {
        let widthDelta: CGFloat = UIConstants.horizontalInset * 2
        let scale = (sourceView.bounds.width - widthDelta) / sourceView.bounds.width
        let heightDiffAfterScale = (sourceView.bounds.height - (sourceView.bounds.height * scale)) / 2
        let yOffset = sourceView.safeAreaInsets.top - heightDiffAfterScale

        let sourceTransform = CGAffineTransform.identity
        let sourceScaleTransform = CGAffineTransform(
            scaleX: scale,
            y: scale
        )
        let sourceTranslateTransform = CGAffineTransform(
            translationX: .zero,
            y: yOffset
        )

        return sourceTransform
            .concatenating(sourceScaleTransform)
            .concatenating(sourceTranslateTransform)
    }

    func createDestinationViewTransform(_ finalFrame: CGRect) -> CGAffineTransform {
        CGAffineTransform(
            translationX: 0,
            y: finalFrame.minY
        )
    }
}

// MARK: UIViewControllerAnimatedTransitioning

extension CardPresentingTransition: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let sourceController = transitionContext.viewController(forKey: .from),
            let destinationController = transitionContext.viewController(forKey: .to)
        else { return }

        let initialDestinationViewFrame = sourceController.view.bounds.offsetBy(
            dx: 0,
            dy: sourceController.view.bounds.maxY
        )
        let finalDestinationViewFrame = sourceController.view.bounds.offsetBy(
            dx: 0,
            dy: CardLayoutPresentationController.topOffset()
        )

        let destinationTransform = createDestinationViewTransform(finalDestinationViewFrame)
        let sourceTransform = createSourceViewTransform(sourceController.view)

        sourceController.view.layer.masksToBounds = true
        destinationController.view.layer.masksToBounds = true
        destinationController.view.frame = initialDestinationViewFrame

        transitionContext.containerView.addSubview(destinationController.view)

        // TODO: Refactor to using BlockViewAnimator after UIKit update to support spring params
        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.4,
            options: .curveEaseIn,
            animations: {
                destinationController.view.transform = destinationTransform
                destinationController.view.frame = finalDestinationViewFrame
                destinationController.view.layer.cornerRadius = Constants.destinationViewCornerRadius

                sourceController.view.layer.cornerRadius = Constants.sourceViewCornerRadius
                sourceController.view.transform = sourceTransform
                sourceController.view.alpha = 0.6
            }
        ) { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

// MARK: Constants

private extension CardPresentingTransition {
    enum Constants {
        static let sourceViewCornerRadius: CGFloat = 12
        static let destinationViewCornerRadius: CGFloat = 16
    }
}
