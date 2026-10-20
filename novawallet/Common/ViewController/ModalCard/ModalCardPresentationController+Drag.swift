import UIKit

struct ModalCardDragState {
    var origin: CGFloat?
    var offset: CGFloat = 0
    var displacement: CGFloat = 0
    var restFrame: CGRect?
    var isDismissable = true
    var canStretch = true
    var settleAnimator: UIViewPropertyAnimator?
}

enum ModalCardRubberBand {
    static let pullDownLimit: CGFloat = 200

    private static let factor: CGFloat = 0.55

    static func displacement(for offset: CGFloat, limit: CGFloat) -> CGFloat {
        (1 - 1 / (offset * factor / limit + 1)) * limit
    }

    static func offset(for displacement: CGFloat, limit: CGFloat) -> CGFloat {
        let ratio = min(displacement / limit, 0.99)

        return limit / factor * (1 / (1 - ratio) - 1)
    }

    static func slope(at offset: CGFloat, limit: CGFloat) -> CGFloat {
        let base = offset * factor / limit + 1

        return factor / (base * base)
    }
}

extension ModalCardPresentationController {
    @objc func didPan(sender: Any?) {
        guard let panGestureRecognizer = sender as? UIPanGestureRecognizer else { return }
        guard let view = panGestureRecognizer.view else { return }

        handlePan(from: panGestureRecognizer, on: view)
    }

    func handlePan(from panGestureRecognizer: UIPanGestureRecognizer, on view: UIView) {
        switch panGestureRecognizer.state {
        case .began, .changed:
            guard interactiveDismissal != nil || !isTransitioning else {
                return
            }

            guard canDrag(basedOn: observedScrollView, with: panGestureRecognizer) else {
                observedScrollView?.isScrollEnabled = true

                return
            }

            drag(with: panGestureRecognizer, on: view)
        case .cancelled, .ended:
            observedScrollView?.isScrollEnabled = true

            release(with: panGestureRecognizer, on: view)
        default:
            break
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

    func rebaseDrag(toRestHeight height: CGFloat) -> Bool {
        guard interactiveDismissal == nil, let restFrame = dragState.restFrame, let presentedView else {
            return false
        }

        let newRestFrame = CGRect(origin: restFrame.origin, size: CGSize(width: restFrame.width, height: height))
        let displacement = dragState.settleAnimator == nil ? dragState.displacement : 0

        dragState.restFrame = newRestFrame
        presentedView.frame = displacedFrame(newRestFrame, by: displacement)

        return true
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
}

private extension ModalCardPresentationController {
    var isTransitioning: Bool {
        presentedViewController.isBeingPresented || presentedViewController.isBeingDismissed
    }

    var stretchLimit: CGFloat {
        max(1, (dragState.restFrame ?? presentedView?.frame ?? .zero).minY)
    }

    func drag(with panGestureRecognizer: UIPanGestureRecognizer, on view: UIView) {
        let translation = panGestureRecognizer.translation(in: view).y
        let origin = dragState.origin ?? beginDrag(at: translation, with: panGestureRecognizer)
        let offset = translation - origin

        dragState.offset = offset
        observedScrollView?.isScrollEnabled = offset <= 0

        if offset > 0, dragState.isDismissable {
            setDisplacement(0)
            updateInteractiveDismissal(for: offset)
        } else if offset > 0 {
            let limit = ModalCardRubberBand.pullDownLimit
            setDisplacement(ModalCardRubberBand.displacement(for: offset, limit: limit))
        } else {
            interactiveDismissal?.update(0)

            let canStretch = dragState.canStretch && interactiveDismissal == nil
            let stretch = ModalCardRubberBand.displacement(for: -offset, limit: stretchLimit)
            setDisplacement(canStretch ? -stretch : 0)
        }
    }

    func beginDrag(at translation: CGFloat, with panGestureRecognizer: UIPanGestureRecognizer) -> CGFloat {
        let displacement = interruptSettling()

        dragState.isDismissable = presentationDelegate?.presentationControllerShouldDismiss(self) ?? true
        dragState.canStretch = displacement < 0 || !isTouchInsideObservedScroll(panGestureRecognizer)

        let start = panGestureRecognizer.state == .began && displacement == 0 ? 0 : translation
        let origin = start - rawOffset(for: displacement)

        dragState.origin = origin

        return origin
    }

    func rawOffset(for displacement: CGFloat) -> CGFloat {
        if displacement < 0 {
            -ModalCardRubberBand.offset(for: -displacement, limit: stretchLimit)
        } else {
            ModalCardRubberBand.offset(for: displacement, limit: ModalCardRubberBand.pullDownLimit)
        }
    }

    func isTouchInsideObservedScroll(_ panGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        guard let observedScrollView, let presentedView else { return false }

        let touchPoint = panGestureRecognizer.location(in: presentedView)

        return presentedView.hitTest(touchPoint, with: nil)?.isDescendant(of: observedScrollView) ?? false
    }

    func updateInteractiveDismissal(for offset: CGFloat) {
        if interactiveDismissal == nil, let presentedView, let containerView {
            interactiveDismissal = ModalCardInteractiveDismissal(
                distance: containerView.frame.maxY - presentedView.frame.minY
            )

            presentedViewController.dismiss(animated: true)
        }

        guard let interactiveDismissal else { return }

        interactiveDismissal.update(offset / interactiveDismissal.distance)
    }

    func release(with panGestureRecognizer: UIPanGestureRecognizer, on view: UIView) {
        guard dragState.origin != nil else { return }

        dragState.origin = nil

        guard interactiveDismissal != nil || !presentedViewController.isBeingDismissed else {
            dragState = ModalCardDragState()
            return
        }

        let velocity = panGestureRecognizer.velocity(in: view).y
        let shouldDismiss = panGestureRecognizer.state == .ended
            && reachesDismissal(offset: dragState.offset, velocity: velocity, height: view.bounds.height)

        if let interactiveDismissal {
            self.interactiveDismissal = nil

            if shouldDismiss {
                finishPresentation(
                    with: { interactiveDismissal.finish(velocity: velocity) },
                    cancelClosure: { interactiveDismissal.cancel(velocity: velocity) }
                )
            } else {
                interactiveDismissal.cancel(velocity: velocity)
            }
        } else if shouldDismiss, !dragState.isDismissable {
            presentationDelegate?.presentationControllerDidAttemptToDismiss(self)
        }

        settle(velocity: displacementVelocity(for: velocity))
    }

    func reachesDismissal(offset: CGFloat, velocity: CGFloat, height: CGFloat) -> Bool {
        let thresholdReached = offset / max(1, height) >= configuration.dismissPercentThreshold

        return (thresholdReached && velocity >= 0) ||
            (velocity >= configuration.dismissVelocityThreshold && offset >= configuration.dismissMinimumOffset)
    }

    func displacementVelocity(for velocity: CGFloat) -> CGFloat {
        if dragState.displacement < 0 {
            velocity * ModalCardRubberBand.slope(at: -dragState.offset, limit: stretchLimit)
        } else if dragState.displacement > 0 {
            velocity * ModalCardRubberBand.slope(at: dragState.offset, limit: ModalCardRubberBand.pullDownLimit)
        } else {
            0
        }
    }

    func setDisplacement(_ displacement: CGFloat) {
        guard displacement != dragState.displacement, let presentedView else { return }

        let restFrame = dragState.restFrame ?? presentedView.frame

        dragState.restFrame = restFrame
        dragState.displacement = displacement

        presentedView.frame = displacedFrame(restFrame, by: displacement)
    }

    func displacedFrame(_ restFrame: CGRect, by displacement: CGFloat) -> CGRect {
        CGRect(
            x: restFrame.minX,
            y: restFrame.minY + displacement,
            width: restFrame.width,
            height: restFrame.height - min(displacement, 0)
        )
    }

    func settle(velocity: CGFloat) {
        guard dragState.displacement != 0, let presentedView, let restFrame = dragState.restFrame else {
            dragState.restFrame = nil
            return
        }

        let animator = ModalCardSpring.createAnimator(velocity: -velocity / dragState.displacement)

        animator.addAnimations {
            presentedView.frame = restFrame
            presentedView.layoutIfNeeded()
        }

        animator.addCompletion { [weak self] _ in
            self?.dragState.restFrame = nil
            self?.dragState.settleAnimator = nil
        }

        dragState.displacement = 0
        dragState.settleAnimator = animator

        animator.startAnimation()
    }

    func interruptSettling() -> CGFloat {
        guard
            let settleAnimator = dragState.settleAnimator,
            let presentedView,
            let restFrame = dragState.restFrame else {
            return 0
        }

        settleAnimator.stopAnimation(true)
        dragState.settleAnimator = nil

        let frame = presentedView.frame
        let displacement = frame.height > restFrame.height
            ? restFrame.height - frame.height
            : frame.minY - restFrame.minY

        dragState.displacement = displacement

        return displacement
    }
}
