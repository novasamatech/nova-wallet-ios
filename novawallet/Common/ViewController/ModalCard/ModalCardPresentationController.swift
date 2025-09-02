import UIKit
import UIKit_iOS

public final class ModalCardPresentationController: UIPresentationController {
    private weak var observedScrollView: UIScrollView?
    private var backgroundView: UIView?

    private let contextRootViewController: UIViewController
    private let configuration: ModalCardPresentationConfiguration
    private let transformFactory: ModalCardPresentationTransformFactoryProtocol

    weak var presentationDelegate: ModalCardPresentationControllerDelegate? {
        presentedViewController as? ModalCardPresentationControllerDelegate
    }

    var interactiveDismissal: UIPercentDrivenInteractiveTransition?
    var initialTranslation: CGPoint = .zero

    init(
        presentedViewController: UIViewController,
        contextRootViewController: UIViewController,
        transformFactory: ModalCardPresentationTransformFactoryProtocol,
        presenting presentingViewController: UIViewController?,
        configuration: ModalCardPresentationConfiguration
    ) {
        self.contextRootViewController = contextRootViewController
        self.configuration = configuration
        self.transformFactory = transformFactory

        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    // MARK: Presentation overridings

    override public var shouldPresentInFullscreen: Bool {
        false
    }

    override public func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()

        configurePresentedView()
        attachPanGesture()
        animateBackground(appearing: true)
    }

    override public func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()

        animateBackground(appearing: false)
    }

    override public var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }

        return calculatePresentedViewFrame(in: containerView)
    }
}

// MARK: Private

private extension ModalCardPresentationController {
    func configureBackgroundView(on view: UIView) {
        if let currentBackgroundView = backgroundView {
            view.addSubview(currentBackgroundView)
        } else {
            let newBackgroundView = UIView(frame: view.bounds)

            newBackgroundView.backgroundColor = configuration.style.backdropColor

            view.addSubview(newBackgroundView)
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
        panGestureRecognizer.cancelsTouchesInView = false
        containerView?.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
    }

    func calculatePresentedViewFrame(in containerView: UIView) -> CGRect {
        let finalFrame: CGRect

        let topOffset: CGFloat = containerView.safeAreaInsets.top + Constants.topOffset

        let finalOrigin = containerView.bounds.offsetBy(
            dx: 0,
            dy: topOffset
        ).origin

        let presentationController = presentingViewController.presentationController
        let presentedByModalCardController = presentationController is ModalCardPresentationController

        let finalHeight: CGFloat = if presentedByModalCardController {
            presentingViewController.view.bounds.height
        } else {
            presentingViewController.view.bounds.height - topOffset
        }

        let finalFrameSize = CGSize(
            width: containerView.bounds.width,
            height: finalHeight
        )

        finalFrame = CGRect(
            origin: finalOrigin,
            size: finalFrameSize
        )

        return finalFrame
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

    func canDrag(
        basedOn scrollView: UIScrollView?,
        with panGesture: UIPanGestureRecognizer
    ) -> Bool {
        guard let scrollView else { return true }
        guard let presentedView, !containsActiveLongPress(scrollView) else { return false }

        let touchPoint = panGesture.location(in: presentedView)

        if let tableView = scrollView as? UITableView, tableView.isEditing {
            return !tableView.frame.contains(touchPoint)
        }

        let contentOffsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let hitView = presentedView.hitTest(touchPoint, with: nil)
        let shouldDrag = contentOffsetY <= 0
            || !(hitView?.isDescendant(of: scrollView) ?? true)

        return shouldDrag
    }

    func containsActiveLongPress(_ scrollView: UIScrollView?) -> Bool {
        guard let recognizers = scrollView?.gestureRecognizers else { return false }

        return recognizers.contains { recognizer in
            if let longPress = recognizer as? UILongPressGestureRecognizer {
                let state = longPress.state

                return state == .began ||
                    state == .changed
            }
            return false
        }
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

            guard canDrag(basedOn: observedScrollView, with: panGestureRecognizer) else {
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
                    (velocity.y >= configuration.dismissVelocityThreshold &&
                        translation.y >= configuration.dismissMinimumOffset)
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

// MARK: Animation

private extension ModalCardPresentationController {
    func animateBackground(appearing: Bool) {
        let animatableProperties = createBackgroundAnimationProperties(for: appearing)
        let coveredContextView = prepareCoveredContextView()

        configureBackgroundView(on: coveredContextView)

        backgroundView?.alpha = animatableProperties.backDropViewInitialAlpha

        let animationBlock: (UIViewControllerTransitionCoordinatorContext) -> Void = { [weak self] _ in
            guard let self else { return }

            backgroundView?.alpha = animatableProperties.backDropViewFinalAlpha
            coveredContextView.layer.cornerRadius = animatableProperties.cornerRadius

            if appearing {
                applySourceAppearanceTransform()
            } else {
                applySourceDismissTransform()
            }
        }

        let completionBlock: (UIViewControllerTransitionCoordinatorContext) -> Void = { [weak self] context in
            guard let self, !appearing, !context.isCancelled else { return }
            completeTransitionAnimation(for: coveredContextView)
        }

        presentingViewController
            .transitionCoordinator?
            .animate(
                alongsideTransition: animationBlock,
                completion: completionBlock
            )
    }

    func createBackgroundAnimationProperties(for appearing: Bool) -> BackgroundProperties {
        let presenterPresentedByOther: Bool = presentingViewController.presentingViewController != nil

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
            cornerRadius = presenterPresentedByOther
                ? Constants.destinationViewCornerRadius
                : UIScreen.main.cornerRadius
        }

        return BackgroundProperties(
            cornerRadius: cornerRadius,
            backDropViewInitialAlpha: alphaFromValue,
            backDropViewFinalAlpha: alphaToValue
        )
    }

    func prepareCoveredContextView() -> UIView {
        let coveredContextView: UIView

        if
            let tabBarController = presentingViewController as? UITabBarController,
            let navController = tabBarController.selectedViewController as? UINavigationController {
            coveredContextView = navController.view
        } else {
            coveredContextView = presentingViewController.navigationController?.view
                ?? presentingViewController.view
        }

        coveredContextView.layer.masksToBounds = true
        coveredContextView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        coveredContextView.layer.cornerCurve = .continuous

        return coveredContextView
    }

    func completeTransitionAnimation(for coveredContextView: UIView) {
        let presenterPresentedByOther: Bool = presentingViewController.presentingViewController != nil

        if presenterPresentedByOther {
            coveredContextView.layer.maskedCorners = presentedView?.layer.maskedCorners ?? []
            coveredContextView.layer.cornerRadius = presentedView?.layer.cornerRadius ?? 0
        } else {
            coveredContextView.layer.cornerRadius = 0
        }
    }
}

// MARK: Public

public extension ModalCardPresentationController {
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
            let containerView
        else { return }

        let presentedViewHeight = presentedView.bounds.height
        let topOffset = containerView.safeAreaInsets.top + Constants.topOffset
        let presenetedViewHeightDelta = contextRootViewController.view.bounds.height - presentedViewHeight - topOffset

        let height = presentedView.frame.height + presenetedViewHeightDelta

        presentedViewController.view.frame = CGRect(
            x: presentedView.frame.origin.x,
            y: presentedView.frame.origin.y,
            width: presentedView.frame.width,
            height: height
        )
    }
}

// MARK: UIGestureRecognizerDelegate

extension ModalCardPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith second: UIGestureRecognizer
    ) -> Bool {
        guard var scrollView = second.view as? UIScrollView else {
            return false
        }

        if let parentScrollView = lookForParentScroll(for: scrollView) {
            scrollView = parentScrollView
        }

        if observedScrollView !== scrollView {
            observedScrollView = scrollView
        }

        return true
    }

    func lookForParentScroll(for scrollView: UIScrollView) -> UIScrollView? {
        var superView: UIView? = scrollView.superview

        while superView != nil {
            if let parentScrollView = superView as? UIScrollView {
                return parentScrollView
            } else {
                superView = superView?.superview
            }
        }

        return nil
    }
}

// MARK: Constants

private extension ModalCardPresentationController {
    enum Constants {
        static let topOffset: CGFloat = 12
        static let sourceViewCornerRadius: CGFloat = 10
        static let destinationViewCornerRadius: CGFloat = 12
    }
}

private struct BackgroundProperties {
    let cornerRadius: CGFloat
    let backDropViewInitialAlpha: CGFloat
    let backDropViewFinalAlpha: CGFloat
}
