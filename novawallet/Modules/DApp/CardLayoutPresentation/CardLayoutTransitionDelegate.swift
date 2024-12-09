import UIKit

protocol CardLayoutTransitionDelegateProtocol {
    func didReceivePanState(
        _ state: UIGestureRecognizer.State,
        translation: CGPoint,
        for view: UIView
    )
}

final class CardLayoutTransitionDelegate: NSObject {
    weak var presentedController: UIViewController?

    private var transition = UIPercentDrivenInteractiveTransition()

    private var started = false
    private var shouldFinish = false

    private var presentDuration: TimeInterval = 0.5
    private var dismissDuration: TimeInterval = 0.25
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

// MARK: UIViewControllerTransitioningDelegate

extension CardLayoutTransitionDelegate: UIViewControllerTransitioningDelegate {
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let finalFrame = dismissed.view.bounds.offsetBy(
            dx: 0,
            dy: dismissed.view.bounds.height
        )

        return CardDismissingAnimator(
            duration: 0.25,
            finalFrame: finalFrame,
            presenterCornerRadius: 12,
            presentedCornerRadius: 16
        )
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        presentedController = presented

        let initialFrame = presenting.view.bounds.offsetBy(
            dx: 0,
            dy: presenting.view.bounds.maxY
        )
        let finalFrame = presenting.view.bounds.offsetBy(
            dx: 0,
            dy: presenting.view.safeAreaInsets.top + 25
        )

        return CardPresentingAnimator(
            duration: presentDuration,
            initialFrame: initialFrame,
            finalFrame: finalFrame,
            presenterCornerRadius: 12,
            presentedCornerRadius: 16
        )
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
