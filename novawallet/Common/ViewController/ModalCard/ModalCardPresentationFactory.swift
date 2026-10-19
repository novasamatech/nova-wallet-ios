import UIKit
import UIKit_iOS

public class ModalCardPresentationFactory: NSObject {
    let configuration: ModalCardPresentationConfiguration
    let presentingViewController: UIViewController
    let contextRootViewController: UIViewController

    weak var presentation: ModalCardPresentationController?

    public init(
        configuration: ModalCardPresentationConfiguration,
        presentingViewController: UIViewController,
        contextRootViewController: UIViewController
    ) {
        self.configuration = configuration
        self.presentingViewController = presentingViewController
        self.contextRootViewController = contextRootViewController

        super.init()
    }
}

// MARK: UIViewControllerTransitioningDelegate

extension ModalCardPresentationFactory: UIViewControllerTransitioningDelegate {
    public func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ModalCardPresentationAppearanceAnimator()
    }

    public func animationController(forDismissed _: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        presentation?.interactiveDismissal?.animator ?? ModalCardPresentationDismissAnimator()
    }

    public func presentationController(
        forPresented presented: UIViewController,
        presenting _: UIViewController?,
        source _: UIViewController
    ) -> UIPresentationController? {
        let presentation = ModalCardPresentationController(
            presentedViewController: presented,
            contextRootViewController: contextRootViewController,
            transformFactory: ModalCardPresentationTransformFactory(),
            presenting: presentingViewController,
            configuration: configuration
        )

        self.presentation = presentation

        return presentation
    }

    public func interactionControllerForDismissal(
        using _: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        presentation?.interactiveDismissal
    }
}

enum ModalCardSpring {
    static let duration: TimeInterval = 0.5

    static func createAnimator(velocity: CGFloat = 0) -> UIViewPropertyAnimator {
        UIViewPropertyAnimator(duration: duration, timingParameters: timing(velocity: velocity))
    }

    static func timing(velocity: CGFloat) -> UISpringTimingParameters {
        UISpringTimingParameters(
            mass: 1,
            stiffness: 350,
            damping: 37.4,
            initialVelocity: CGVector(dx: velocity, dy: velocity)
        )
    }
}

public final class ModalCardPresentationAppearanceAnimator: NSObject {
    private var animator: UIViewPropertyAnimator?
}

// MARK: UIViewControllerAnimatedTransitioning

extension ModalCardPresentationAppearanceAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        ModalCardSpring.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    public func interruptibleAnimator(
        using transitionContext: UIViewControllerContextTransitioning
    ) -> UIViewImplicitlyAnimating {
        if let animator {
            return animator
        }

        let animator = ModalCardSpring.createAnimator()

        if let presentedController = transitionContext.viewController(forKey: .to) {
            let finalFrame = transitionContext.finalFrame(for: presentedController)

            presentedController.view.frame = finalFrame.offsetBy(dx: 0, dy: finalFrame.height)
            transitionContext.containerView.addSubview(presentedController.view)

            animator.addAnimations {
                presentedController.view.frame = finalFrame
            }
        }

        animator.addCompletion { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        self.animator = animator

        return animator
    }

    public func animationEnded(_: Bool) {
        animator = nil
    }
}

public final class ModalCardPresentationDismissAnimator: NSObject {
    private var animator: UIViewPropertyAnimator?
}

// MARK: UIViewControllerAnimatedTransitioning

extension ModalCardPresentationDismissAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        ModalCardSpring.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        interruptibleAnimator(using: transitionContext).startAnimation()
    }

    public func interruptibleAnimator(
        using transitionContext: UIViewControllerContextTransitioning
    ) -> UIViewImplicitlyAnimating {
        if let animator {
            return animator
        }

        let animator = ModalCardSpring.createAnimator()
        let presentedController = transitionContext.viewController(forKey: .from)

        if let presentedView = presentedController?.view {
            var finalFrame = presentedView.frame
            finalFrame.origin.y = transitionContext.containerView.frame.maxY

            animator.addAnimations {
                presentedView.frame = finalFrame
            }
        }

        animator.addCompletion { _ in
            if !transitionContext.transitionWasCancelled {
                presentedController?.view.removeFromSuperview()
            }

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        self.animator = animator

        return animator
    }

    public func animationEnded(_: Bool) {
        animator = nil
    }
}

final class ModalCardInteractiveDismissal: NSObject {
    let animator = ModalCardPresentationDismissAnimator()
    let distance: CGFloat

    private var transitionContext: UIViewControllerContextTransitioning?
    private var transitionAnimator: UIViewImplicitlyAnimating?
    private var fraction: CGFloat = 0
    private var pendingCompletion: (finished: Bool, velocity: CGFloat)?

    init(distance: CGFloat) {
        self.distance = max(distance, 1)

        super.init()
    }

    func update(_ newFraction: CGFloat) {
        fraction = min(max(newFraction, 0), 1)
        transitionAnimator?.fractionComplete = fraction
        transitionContext?.updateInteractiveTransition(fraction)
    }

    func finish(velocity: CGFloat) {
        complete(finished: true, velocity: velocity)
    }

    func cancel(velocity: CGFloat) {
        complete(finished: false, velocity: velocity)
    }
}

private extension ModalCardInteractiveDismissal {
    func complete(finished: Bool, velocity: CGFloat) {
        guard let transitionContext, let transitionAnimator else {
            pendingCompletion = (finished, velocity)
            return
        }

        let remainingDistance = (finished ? 1 - fraction : fraction) * distance
        let towardsTarget = finished ? velocity : -velocity
        let relativeVelocity = remainingDistance > 1 ? towardsTarget / remainingDistance : 0

        if finished {
            transitionContext.finishInteractiveTransition()
        } else {
            transitionContext.cancelInteractiveTransition()
            transitionAnimator.isReversed = true
        }

        transitionAnimator.continueAnimation?(
            withTimingParameters: ModalCardSpring.timing(velocity: relativeVelocity),
            durationFactor: 1
        )
    }
}

// MARK: UIViewControllerInteractiveTransitioning

extension ModalCardInteractiveDismissal: UIViewControllerInteractiveTransitioning {
    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        let transitionAnimator = animator.interruptibleAnimator(using: transitionContext)

        transitionAnimator.pauseAnimation()
        transitionAnimator.fractionComplete = fraction

        self.transitionContext = transitionContext
        self.transitionAnimator = transitionAnimator

        if let pendingCompletion {
            self.pendingCompletion = nil
            complete(finished: pendingCompletion.finished, velocity: pendingCompletion.velocity)
        }
    }
}
