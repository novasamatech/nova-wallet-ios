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
        ModalCardPresentationAppearanceAnimator(animator: configuration.contentAppearanceAnimator)
    }

    public func animationController(forDismissed _: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        ModalCardPresentationDismissAnimator(
            animator: configuration.contentDissmisalAnimator,
            finalPositionOffset: 0.0
        )
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

public final class ModalCardPresentationAppearanceAnimator: NSObject {
    let animator: BlockViewAnimatorProtocol

    public init(animator: BlockViewAnimatorProtocol) {
        self.animator = animator

        super.init()
    }
}

// MARK: UIViewControllerAnimatedTransitioning

extension ModalCardPresentationAppearanceAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        animator.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .to) else {
            return
        }

        let finalFrame = transitionContext.finalFrame(for: presentedController)
        var initialFrame = finalFrame
        initialFrame.origin.y += finalFrame.size.height

        presentedController.view.frame = initialFrame
        transitionContext.containerView.addSubview(presentedController.view)

        let animationBlock: () -> Void = {
            presentedController.view.frame = finalFrame
        }

        let completionBlock: (Bool) -> Void = { finished in
            transitionContext.completeTransition(finished)
        }

        // TODO: Use spring-block animator after UIKit update
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.4,
            options: .curveEaseIn,
            animations: animationBlock,
            completion: completionBlock
        )
    }
}

public final class ModalCardPresentationDismissAnimator: NSObject {
    let animator: BlockViewAnimatorProtocol
    let finalPositionOffset: CGFloat

    public init(
        animator: BlockViewAnimatorProtocol,
        finalPositionOffset: CGFloat
    ) {
        self.animator = animator
        self.finalPositionOffset = finalPositionOffset

        super.init()
    }
}

// MARK: UIViewControllerAnimatedTransitioning

extension ModalCardPresentationDismissAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        animator.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .from) else {
            return
        }

        let initialFrame = presentedController.view.frame
        var finalFrame = initialFrame
        finalFrame.origin.y = transitionContext.containerView.frame.maxY + finalPositionOffset

        let animationBlock: () -> Void = {
            presentedController.view.frame = finalFrame
        }

        let completionBlock: (Bool) -> Void = { _ in
            if !transitionContext.transitionWasCancelled {
                presentedController.view.removeFromSuperview()
            }

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animator.animate(
            block: animationBlock,
            completionBlock: completionBlock
        )
    }
}
