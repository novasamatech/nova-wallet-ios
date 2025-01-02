import UIKit
import SoraUI

protocol ModalCardPresentationControllerDelegate: AnyObject {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool
    func presentationControllerDidAttemptToDismiss(_: UIPresentationController)
}

class ModalCardPresentationController: UIPresentationController {
    private weak var observedScrollView: UIScrollView?
    private var backgroundView: UIView?

    let configuration: ModalCardPresentationConfiguration
    let transformFactory: ModalCardPresentationTransformFactoryProtocol

    weak var presentationDelegate: ModalCardPresentationControllerDelegate? {
        presentedViewController as? ModalCardPresentationControllerDelegate
    }

    var interactiveDismissal: UIPercentDrivenInteractiveTransition?
    var initialTranslation: CGPoint = .zero

    let topOffset: CGFloat = (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0) + 12

    init(
        presentedViewController: UIViewController,
        transformFactory: ModalCardPresentationTransformFactoryProtocol,
        presenting presentingViewController: UIViewController?,
        configuration: ModalCardPresentationConfiguration
    ) {
        self.configuration = configuration
        self.transformFactory = transformFactory

        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    // MARK: Presentation overridings

    override var shouldPresentInFullscreen: Bool {
        false
    }

    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()

        guard let sourceView = presentingViewController.view else { return }

        configureBackgroundView(on: sourceView)
        configurePresentedView()

        attachPanGesture()

        animateBackground(appearing: true)
    }

    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()

        animateBackground(appearing: false)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }

        return calculatePresentedViewFrame(in: containerView)
    }

    func applySourceDismissTransform() {
        guard let sourceView = presentingViewController.view else { return }

        let transform = transformFactory.createDismissingTransform(for: presentingViewController)

        sourceView.transform = transform

        let parentPresentationController = presentingViewController.presentationController
            as? ModalCardPresentationController

        parentPresentationController?.applySourceDismissTransform()
    }

    func applySourceAppearanceTransform() {
        guard let sourceView = presentingViewController.view else { return }

        let transform = transformFactory.createAppearanceTransform(for: presentingViewController)

        sourceView.transform = transform

        let parentPresentationController = presentingViewController.presentationController
            as? ModalCardPresentationController

        parentPresentationController?.applySourceAppearanceTransform()
    }

    func updateLayout() {
        guard
            let presentedView,
            let root = UIApplication.shared.tabBarController
        else { return }

        let presentedViewHeight = presentedView.bounds.height
        var presenetedViewHeightDelta = root.view.bounds.height - presentedViewHeight - topOffset

        let height = presentedViewController.view.frame.height + presenetedViewHeightDelta

        presentedViewController.view.frame = CGRect(
            x: presentedView.frame.origin.x,
            y: presentedView.frame.origin.y,
            width: presentedView.frame.width,
            height: height
        )
    }
}

// MARK: Private

private extension ModalCardPresentationController {
    func configureBackgroundView(on view: UIView) {
        if let currentBackgroundView = backgroundView {
            view.insertSubview(currentBackgroundView, at: 0)
        } else {
            let newBackgroundView = UIView(frame: view.bounds)

            newBackgroundView.backgroundColor = configuration.style.backdropColor

            view.insertSubview(newBackgroundView, at: 0)
            backgroundView = newBackgroundView
        }

        backgroundView?.frame = view.bounds
    }

    func configurePresentedView() {
        presentedViewController.view.layer.masksToBounds = true
        presentedViewController.view.layer.cornerRadius = Constants.destinationViewCornerRadius
    }

    func attachPanGesture() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(sender:)))
        containerView?.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
    }

    func calculatePresentedViewFrame(in containerView: UIView) -> CGRect {
        let finalFrame: CGRect

        let finalOrigin = containerView.bounds.offsetBy(
            dx: 0,
            dy: topOffset
        ).origin

        let finalFrameSize = CGSize(
            width: containerView.bounds.width,
            height: (UIApplication.shared.tabBarController?.view.bounds.height ?? 0) - topOffset
        )

        finalFrame = CGRect(
            origin: finalOrigin,
            size: finalFrameSize
        )

        return finalFrame
    }

    // MARK: Animation

    func animateBackground(appearing: Bool) {
        let isPresentedByNavigationController: Bool = presentingViewController is UINavigationController

        let alphaFromValue: CGFloat
        let alphaToValue: CGFloat
        let cornerRadius: CGFloat

        if appearing {
            alphaFromValue = 0.0
            alphaToValue = 1.0
            cornerRadius = Constants.sourceViewCornerRadius
        } else {
            alphaFromValue = 1.0
            alphaToValue = 0.0
            cornerRadius = isPresentedByNavigationController ? Constants.sourceViewCornerRadius : 45
        }

        let coveredContextView: UIView?

        if let tabBarController = presentingViewController as? UITabBarController {
            let navController = tabBarController.selectedViewController as? UINavigationController
            coveredContextView = navController?.topViewController?.view ?? tabBarController.view
        } else {
            coveredContextView = presentingViewController.view
        }

        coveredContextView?.layer.masksToBounds = true
        backgroundView?.alpha = alphaFromValue

        let animationBlock: (UIViewControllerTransitionCoordinatorContext) -> Void = { [weak self] _ in
            guard let self else { return }

            backgroundView?.alpha = alphaToValue
            coveredContextView?.layer.cornerRadius = cornerRadius

            if appearing {
                applySourceAppearanceTransform()
            } else {
                applySourceDismissTransform()
            }
        }

        presentingViewController
            .transitionCoordinator?
            .animate(
                alongsideTransition: animationBlock,
                completion: nil
            )
    }

    func dismiss(animated: Bool) {
        finishPresentation(
            with: { self.presentedViewController.dismiss(animated: animated, completion: nil) },
            cancelClosure: nil
        )
    }

    func stopPullToDismiss(finished: Bool) {
        guard let interactiveDismissal else { return }

        self.interactiveDismissal = nil

        if finished {
            interactiveDismissal.completionSpeed = configuration.dismissFinishSpeedFactor
            finishPresentation(
                with: interactiveDismissal.finish,
                cancelClosure: interactiveDismissal.cancel
            )
        } else {
            interactiveDismissal.completionSpeed = configuration.dismissCancelSpeedFactor
            interactiveDismissal.cancel()
        }
    }

    func finishPresentation(
        with finishClosure: () -> Void,
        cancelClosure: (() -> Void)?
    ) {
        if let presentationDelegate {
            if presentationDelegate.presentationControllerShouldDismiss(self) {
                finishClosure()
            } else {
                cancelClosure?()
                presentationDelegate.presentationControllerDidAttemptToDismiss(self)
            }
        } else {
            finishClosure()
        }
    }

    func canDrag(basedOn scrollView: UIScrollView?) -> Bool {
        guard let scrollView else { return true }

        let contentOffsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top

        return contentOffsetY <= 0
    }

    // MARK: Interactive dismissal

    func handlePan(from panGestureRecognizer: UIPanGestureRecognizer, on view: UIView) {
        let translation = panGestureRecognizer.translation(in: view)
        let velocity = panGestureRecognizer.velocity(in: view)

        switch panGestureRecognizer.state {
        case .began, .changed:
            let scrollProgress = max(0.0, (translation.y - initialTranslation.y) / max(1.0, view.bounds.size.height))
            let progress = min(1.0, scrollProgress)
            let scrolledFromTop = translation.y <= 0 && scrollProgress == 0

            guard canDrag(basedOn: observedScrollView) else {
                observedScrollView?.isScrollEnabled = true

                return
            }

            observedScrollView?.isScrollEnabled = scrolledFromTop

            if let interactiveDismissal {
                interactiveDismissal.update(progress)
            } else {
                interactiveDismissal = UIPercentDrivenInteractiveTransition()
                initialTranslation = translation
                presentedViewController.dismiss(animated: true)
                interactiveDismissal?.update(progress)
            }
        case .cancelled, .ended:
            observedScrollView?.isScrollEnabled = true

            if let interactiveDismissal = interactiveDismissal {
                let thresholdReached = interactiveDismissal.percentComplete >= configuration.dismissPercentThreshold
                let shouldDismiss = (thresholdReached && velocity.y >= 0) ||
                    (velocity.y >= configuration.dismissVelocityThreshold && translation.y >= configuration.dismissMinimumOffset)
                stopPullToDismiss(finished: panGestureRecognizer.state != .cancelled && shouldDismiss)
            }
        default:
            break
        }
    }

    // MARK: Action

    @objc func didPan(sender: Any?) {
        guard let panGestureRecognizer = sender as? UIPanGestureRecognizer else { return }
        guard let view = panGestureRecognizer.view else { return }

        handlePan(from: panGestureRecognizer, on: view)
    }
}

// MARK: UIGestureRecognizerDelegate

extension ModalCardPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith second: UIGestureRecognizer
    ) -> Bool {
        guard let scrollView = second.view as? UIScrollView else {
            return false
        }

        if observedScrollView !== scrollView {
            observedScrollView = scrollView
        }

        return true
    }
}

// MARK: Constants

private extension ModalCardPresentationController {
    enum Constants {
        static let sourceViewCornerRadius: CGFloat = 12
        static let destinationViewCornerRadius: CGFloat = 16
    }
}
