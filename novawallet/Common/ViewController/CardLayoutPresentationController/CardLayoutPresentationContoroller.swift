import UIKit

final class CardLayoutPresentationController: UIViewController {
    // we keep strong reference to delegate pan gesture processing
    // because translation change is tied with transition.
    // Delegate doesn't retains controller so we're safe here

    // swiftlint:disable weak_delegate
    private let transitionDelegate: CardLayoutTransitionDelegateProtocol

    init(transitionDelegate: CardLayoutTransitionDelegateProtocol) {
        self.transitionDelegate = transitionDelegate

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupActions()
    }

    static func topOffset() -> CGFloat {
        (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0) + 12
    }
}

// MARK: Internal

extension CardLayoutPresentationController {
    func updateLayout() {
        guard let presentingView = presentingViewController?.view else { return }

        view.frame = CGRect(
            x: view.frame.minX,
            y: view.frame.minY,
            width: presentingView.bounds.width,
            height: presentingView.bounds.height
        )
    }
}

// MARK: Private

private extension CardLayoutPresentationController {
    func setupActions() {
        let pan = UIPanGestureRecognizer(
            target: self,
            action: #selector(panGesture(_:))
        )

        view.addGestureRecognizer(pan)
    }

    @objc func panGesture(_ sender: UIPanGestureRecognizer) {
        transitionDelegate.didReceivePanState(
            sender.state,
            translation: sender.translation(in: view),
            for: view
        )
    }
}
