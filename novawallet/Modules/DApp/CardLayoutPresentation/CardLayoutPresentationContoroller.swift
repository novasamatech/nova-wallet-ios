import UIKit

final class CardLayoutPresentationContoroller: UIViewController {
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

        setupPanGesture()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed {
            onDisappear?()
        }
    }
}

// MARK: Private

private extension CardLayoutPresentationContoroller {
    func setupPanGesture() {
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

extension UIViewController {
    func presentWithCardLayout(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let transitioningDelegate = CardLayoutTransitionDelegate()
        let container = CardLayoutPresentationContoroller(transitionDelegate: transitioningDelegate)

        container.addChild(viewController)
        container.view.addSubview(viewController.view)

        viewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        container.view.layoutIfNeeded()

        container.didMove(toParent: viewController)

        container.transitioningDelegate = transitioningDelegate
        container.modalPresentationStyle = .overCurrentContext

        if let tabBarController = navigationController?.parent as? UITabBarController {
            tabBarController.tabBar.isHidden = true

            container.onDisappear = {
                tabBarController.tabBar.isHidden = false
            }
        }

        present(
            container,
            animated: animated,
            completion: completion
        )
    }
}
