import UIKit
import UIKit_iOS

extension UIViewController {
    func presentWithCardLayout(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let contextRootViewController = viewController.tabBarController
            ?? UIApplication.shared.rootContainer
            ?? viewController.navigationController
            ?? viewController

        let configuration = ModalCardPresentationConfiguration(
            style: ModalCardPresentationStyle.defaultStyle,
            extendUnderSafeArea: true
        )

        let factory = ModalCardPresentationFactory(
            configuration: configuration,
            presentingViewController: self,
            contextRootViewController: contextRootViewController
        )

        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom
        viewController.definesPresentationContext = true

        present(
            viewController,
            animated: animated,
            completion: completion
        )
    }
}
