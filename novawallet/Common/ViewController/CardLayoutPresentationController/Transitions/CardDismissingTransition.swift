import UIKit
import SoraUI

final class CardDismissingTransition: NSObject {
    private let transitionDuration: TimeInterval
    private let animator: BlockViewAnimatorProtocol
    private let dimmingViewTag: Int

    init(
        transitionDuration: TimeInterval = 0.25,
        animator: BlockViewAnimatorProtocol,
        dimmingViewTag: Int
    ) {
        self.transitionDuration = transitionDuration
        self.animator = animator
        self.dimmingViewTag = dimmingViewTag

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

        let coveredContextView: UIView

        if let tabBarController = destinationController as? UITabBarController {
            let navController = tabBarController.selectedViewController as? UINavigationController
            coveredContextView = navController?.topViewController?.view ?? tabBarController.view
        } else {
            coveredContextView = destinationController.view
        }

        let sourceFrame = sourceController.view.bounds.offsetBy(
            dx: 0,
            dy: sourceController.view.bounds.height
        )

        coveredContextView.layer.masksToBounds = true

        let dimmingView = coveredContextView.subviews.first { $0.tag == dimmingViewTag }

        animator.animate {
            destinationController.view.transform = .identity
            coveredContextView.layer.cornerRadius = 0
            dimmingView?.alpha = 0

            sourceController.view.frame = sourceFrame
        } completionBlock: { _ in
            if !transitionContext.transitionWasCancelled {
                dimmingView?.removeFromSuperview()
            }

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
