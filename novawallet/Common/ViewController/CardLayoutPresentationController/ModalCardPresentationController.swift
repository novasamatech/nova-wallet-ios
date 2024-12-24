import UIKit
import SoraUI

class ModalCardPresentationController: UIPresentationController {
    let configuration: ModalCardPresentationConfiguration

    private var backgroundView: UIView?

    var interactiveDismissal: UIPercentDrivenInteractiveTransition?
    var initialTranslation: CGPoint = .zero

    var presenterDelegate: ModalPresenterDelegate? {
        (presentedViewController as? ModalPresenterDelegate) ??
            (presentedView as? ModalPresenterDelegate) ??
            (presentedViewController.view as? ModalPresenterDelegate)
    }

    var sheetPresenterDelegate: ModalSheetPresenterDelegate? {
        presenterDelegate as? ModalSheetPresenterDelegate
    }

    var inputView: ModalViewProtocol? {
        (presentedViewController as? ModalViewProtocol) ??
            (presentedView as? ModalViewProtocol) ??
            (presentedViewController.view as? ModalViewProtocol)
    }

    init(
        presentedViewController: UIViewController,
        presenting presentingViewController: UIViewController?,
        configuration: ModalCardPresentationConfiguration
    ) {
        self.configuration = configuration

        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)

        if let modalInputView = inputView {
            modalInputView.presenter = self
        }
    }

    // MARK: Presentation overridings

    override func presentationTransitionWillBegin() {
        guard let sourceView = presentingViewController.view else { return }

        configureBackgroundView(on: sourceView)

        attachPanGesture()

        animateBackground(appearing: true)
    }

    override func dismissalTransitionWillBegin() {
        animateBackground(appearing: false)
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()

        guard let containerView else { return }

        backgroundView?.frame = containerView.bounds

        let presentedFrame = frameOfPresentedViewInContainerView
        presentedViewController.view.frame = presentedFrame
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }

        return calculatePresentedViewFrame(in: containerView)
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

    func attachPanGesture() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(sender:)))
        containerView?.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
    }

    func calculatePresentedViewFrame(in containerView: UIView) -> CGRect {
        let finalOrigin = containerView.bounds.offsetBy(
            dx: 0,
            dy: CardLayoutPresentationController.topOffset()
        ).origin

        let finalFrameSize = CGSize(
            width: containerView.bounds.width,
            height: containerView.bounds.height - CardLayoutPresentationController.topOffset() - 84 // temporary 
        )

        let finalFrame = CGRect(
            origin: finalOrigin,
            size: finalFrameSize
        )

        return finalFrame
    }

    // MARK: Animation

    func animateBackground(appearing: Bool) {
        let presentingViewControllerr = presentingViewController

        let alphaFromValue: CGFloat
        let alphaToValue: CGFloat
        let transform: CGAffineTransform

        if appearing {
            alphaFromValue = 0.0
            alphaToValue = 1.0
            transform = createAppearBackgroundTransform()
        } else {
            alphaFromValue = 1.0
            alphaToValue = 0.0
            transform = createDisappearBackgroundTransform()
        }

        backgroundView?.alpha = alphaFromValue

        let animationBlock: (UIViewControllerTransitionCoordinatorContext) -> Void = { _ in
            let key: UITransitionContextViewControllerKey = appearing ? .from : .to

            self.backgroundView?.alpha = alphaToValue
            presentingViewControllerr.view.transform = transform
        }

        presentingViewController
            .transitionCoordinator?
            .animate(
                alongsideTransition: animationBlock,
                completion: nil
            )
    }

    func createAppearBackgroundTransform() -> CGAffineTransform {
        guard let sourceView = presentingViewController.view else { return .identity }

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

    func createDisappearBackgroundTransform() -> CGAffineTransform {
        CGAffineTransform.identity
    }

    func dismiss(animated: Bool) {
        presentedViewController.dismiss(animated: animated, completion: nil)
    }

    func stopPullToDismiss(finished: Bool) {
        guard let interactiveDismissal else { return }

        self.interactiveDismissal = nil

        if finished {
            interactiveDismissal.completionSpeed = configuration.dismissFinishSpeedFactor
            interactiveDismissal.finish()

            presenterDelegate?.presenterDidHide(self)
        } else {
            interactiveDismissal.completionSpeed = configuration.dismissCancelSpeedFactor
            interactiveDismissal.cancel()
        }
    }

    // MARK: Interactive dismissal

    func handlePan(from panGestureRecognizer: UIPanGestureRecognizer, on view: UIView) {
        let translation = panGestureRecognizer.translation(in: view)
        let velocity = panGestureRecognizer.velocity(in: view)

        switch panGestureRecognizer.state {
        case .began, .changed:
            if sheetPresenterDelegate?.presenterCanDrag(self) == false {
                return
            }
            if let interactiveDismissal = interactiveDismissal {
                let progress = min(1.0, max(0.0, (translation.y - initialTranslation.y) / max(1.0, view.bounds.size.height)))

                interactiveDismissal.update(progress)
            } else {
                if let presenterDelegate = presenterDelegate, !presenterDelegate.presenterShouldHide(self) {
                    break
                }

                interactiveDismissal = UIPercentDrivenInteractiveTransition()
                initialTranslation = translation
                presentedViewController.dismiss(animated: true)
            }
        case .cancelled, .ended:
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

    @objc func actionDidCancel(gesture _: UITapGestureRecognizer) {
        guard let presenterDelegate else {
            dismiss(animated: true)
            return
        }

        if presenterDelegate.presenterShouldHide(self) {
            dismiss(animated: true)
            presenterDelegate.presenterDidHide(self)
        }
    }

    @objc func didPan(sender: Any?) {
        guard let panGestureRecognizer = sender as? UIPanGestureRecognizer else { return }
        guard let view = panGestureRecognizer.view else { return }

        handlePan(from: panGestureRecognizer, on: view)
    }
}

// MARK: ModalPresenterProtocol

extension ModalCardPresentationController: ModalPresenterProtocol {
    func hide(view _: ModalViewProtocol, animated: Bool) {
        guard interactiveDismissal == nil else {
            return
        }

        dismiss(animated: animated)
    }
}

// MARK: UIGestureRecognizerDelegate

extension ModalCardPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
