import UIKit

extension UIViewController {
    func presentWithCardLayout(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let transitioningDelegate = CardLayoutTransitionDelegate()
        let container = CardLayoutPresentationController(transitionDelegate: transitioningDelegate)

        container.addChild(viewController)
        container.view.addSubview(viewController.view)

        viewController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        container.view.layoutIfNeeded()

        container.didMove(toParent: viewController)

        container.transitioningDelegate = transitioningDelegate
        container.modalPresentationStyle = .overCurrentContext

        setTabBarHidden(true, animated: animated)

        container.onDisappear = { [weak self] in
            self?.setTabBarHidden(false, animated: animated)
        }

        present(
            container,
            animated: animated,
            completion: completion
        )
    }
}
