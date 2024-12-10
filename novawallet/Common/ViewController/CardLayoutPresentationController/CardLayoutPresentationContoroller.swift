import UIKit

final class CardLayoutPresentationController: UIViewController {
    // we keep strong reference to delegate pan gesture processing
    // because translation change is tied with transition.
    // Delegate doesn't retains controller so we're safe here

    // swiftlint:disable weak_delegate
    private let transitionDelegate: CardLayoutTransitionDelegateProtocol

    var onDisappear: (() -> Void)?

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed {
            onDisappear?()
        }
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
