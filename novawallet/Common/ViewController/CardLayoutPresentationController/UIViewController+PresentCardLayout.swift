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
            make.top.trailing.leading.equalToSuperview()
            make.bottom.equalToSuperview().inset(CardLayoutPresentationController.topOffset())
        }
        container.view.layoutIfNeeded()
        container.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        container.didMove(toParent: viewController)

        container.transitioningDelegate = transitioningDelegate
        container.modalPresentationStyle = .overCurrentContext

        tabBarController?.present(
            container,
            animated: animated,
            completion: completion
        )
    }
}
