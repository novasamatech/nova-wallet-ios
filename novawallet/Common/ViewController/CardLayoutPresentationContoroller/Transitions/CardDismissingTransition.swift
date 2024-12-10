import UIKit
import SoraUI

final class CardDismissingTransition: NSObject {
    private let transitionDuration: TimeInterval
    private let animator: BlockViewAnimatorProtocol

    init(
        transitionDuration: TimeInterval = 0.25,
        animator: BlockViewAnimatorProtocol
    ) {
        self.transitionDuration = transitionDuration
        self.animator = animator

        super.init()
    }
}

// MARK: UIViewControllerAnimatedTransitioning

extension CardDismissingTransition: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        transitionDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let sourceController = transitionContext.viewController(
                forKey: UITransitionContextViewControllerKey.from
            ),
            let destinationController = transitionContext.viewController(
                forKey: UITransitionContextViewControllerKey.to
            )
        else { return }

        let sourceFrame = sourceController.view.bounds.offsetBy(
            dx: 0,
            dy: sourceController.view.bounds.height
        )

        destinationController.view.layer.masksToBounds = true

        animator.animate {
            destinationController.view.transform = .identity
            destinationController.view.layer.cornerRadius = 0
            destinationController.view.alpha = 1

            sourceController.view.frame = sourceFrame
        } completionBlock: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
