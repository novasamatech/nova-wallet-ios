import UIKit
import UIKit_iOS

protocol SharedStatusPresenterDelegate: AnyObject {
    func didTapSharedStatusView()
}

final class SharedStatusPresenter {
    let pendingColor: UIColor = R.color.colorIconAccent()!
    let completionColor: UIColor = R.color.colorIconPositive()!

    weak var delegate: SharedStatusPresenterDelegate?

    let appearanceAnimation = BlockViewAnimator(
        duration: 0.2,
        delay: 0,
        options: .curveLinear
    )

    let transitionAnimation = BlockViewAnimator(
        duration: 0.2,
        delay: 0,
        options: .curveEaseIn
    )

    let dismissalDelay: TimeInterval = 1.5

    let preferredHeight: CGFloat = 9

    private var sharedView: ApplicationStatusView?

    private var scheduler: SchedulerProtocol?

    private func dissmissView() {
        guard let sharedView = sharedView else {
            return
        }

        var newFrame = sharedView.frame
        newFrame.origin.y = -newFrame.height

        appearanceAnimation.animate(block: {
            sharedView.frame = newFrame
        }, completionBlock: { [weak self] completed in
            guard completed else {
                return
            }

            sharedView.removeFromSuperview()
            self?.sharedView = nil
        })
    }

    private func getSharedStatusView() -> ApplicationStatusView {
        if let sharedView {
            return sharedView
        } else {
            let topMargin = UIApplication.shared.statusBarFrame.size.height
            let width = UIApplication.shared.statusBarFrame.size.width
            let height = topMargin + preferredHeight

            let origin = CGPoint(x: 0.0, y: -height)
            let frame = CGRect(origin: origin, size: CGSize(width: width, height: height))
            let view = ApplicationStatusView(frame: frame)
            view.titleLabel.apply(
                style: .init(
                    textColor: R.color.colorTextPrimary(),
                    font: .semiBoldFootnote
                )
            )

            view.contentInsets = UIEdgeInsets(top: topMargin / 2.0, left: 0, bottom: 3, right: 0)
            sharedView = view

            view.addGestureRecognizer(
                BindableGestureRecognizer { [weak self] in
                    self?.delegate?.didTapSharedStatusView()
                }
            )

            return view
        }
    }

    private func cancelScheduler() {
        scheduler?.cancel()
        scheduler = nil
    }

    private func scheduleDismiss() {
        cancelScheduler()

        scheduler = Scheduler(with: self, callbackQueue: .main)
        scheduler?.notifyAfter(dismissalDelay)
    }

    private func makeSuccessFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

extension SharedStatusPresenter {
    func showPending(for message: String, on view: UIView) {
        let currentView = getSharedStatusView()

        currentView.backgroundColor = pendingColor
        currentView.titleLabel.text = message

        cancelScheduler()

        var newFrame = currentView.frame
        newFrame.origin = .zero

        if currentView.superview === view {
            currentView.layer.removeAllAnimations()
            currentView.frame = newFrame
            currentView.setNeedsLayout()

            return
        }

        view.addSubview(currentView)

        appearanceAnimation.animate(block: {
            currentView.frame = newFrame
        }, completionBlock: nil)
    }

    func complete(with message: String) {
        guard let sharedView = sharedView else {
            return
        }

        cancelScheduler()

        transitionAnimation.animate(
            block: {
                sharedView.titleLabel.text = message
                sharedView.backgroundColor = self.completionColor
            },
            completionBlock: { [weak self] completed in
                guard completed else {
                    return
                }

                self?.makeSuccessFeedback()
                self?.scheduleDismiss()
            }
        )
    }

    func hide() {
        guard sharedView != nil else {
            return
        }

        cancelScheduler()

        dissmissView()
    }
}

extension SharedStatusPresenter: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        scheduler = nil

        dissmissView()
    }
}
