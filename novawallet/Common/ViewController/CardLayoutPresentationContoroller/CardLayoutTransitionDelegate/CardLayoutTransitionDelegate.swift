import UIKit
import SoraUI

final class CardLayoutTransitionDelegate: NSObject {
    private weak var presentedController: UIViewController?

    private var transition = UIPercentDrivenInteractiveTransition()

    private var started = false
    private var shouldFinish = false
}

// MARK: UIViewControllerTransitioningDelegate

extension CardLayoutTransitionDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forDismissed _: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animator = BlockViewAnimator(duration: Constants.dismissTransitionDuration)

        return CardDismissingTransition(
            transitionDuration: Constants.dismissTransitionDuration,
            animator: animator
        )
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        presentedController = presented

        return CardPresentingTransition(transitionDuration: Constants.presentTransitionDuration)
    }

    func interactionControllerForDismissal(
        using _: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        started
            ? transition
            : nil
    }

    func interactionControllerForPresentation(
        using _: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        started
            ? transition
            : nil
    }
}

// MARK: CardLayoutTransitionDelegateProtocol

extension CardLayoutTransitionDelegate: CardLayoutTransitionDelegateProtocol {
    func didReceivePanState(
        _ state: UIGestureRecognizer.State,
        translation: CGPoint,
        for view: UIView
    ) {
        let percentThreshold: CGFloat = 0.1

        let verticalMovement = translation.y / view.bounds.height
        let downwardMovement = fmaxf(Float(verticalMovement), 0.0)
        let downwardMovementPercent = fminf(downwardMovement, 1.0)
        let progress = CGFloat(downwardMovementPercent)

        switch state {
        case .began:
            started = true
            presentedController?.dismiss(
                animated: true,
                completion: nil
            )
        case .changed:
            shouldFinish = progress > percentThreshold
            transition.update(progress)
        case .cancelled:
            started = false
            transition.cancel()
        case .ended:
            started = false

            if shouldFinish {
                transition.finish()
            } else {
                transition.cancel()
            }
        default:
            break
        }
    }
}

// MARK: Constants

private extension CardLayoutTransitionDelegate {
    enum Constants {
        static let presentTransitionDuration: TimeInterval = 0.5
        static let dismissTransitionDuration: TimeInterval = 0.25
    }
}
