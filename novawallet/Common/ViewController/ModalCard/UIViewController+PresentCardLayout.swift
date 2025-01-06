import UIKit
import SoraUI

extension UIViewController {
    func presentWithCardLayout(
        _ viewController: UIViewController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let contextRootViewController = UIApplication.shared.tabBarController ?? UIApplication.shared.rootContainer

        guard let contextRootViewController else { return }

        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let appearanceAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveEaseOut]
        )
        let dismissalAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveLinear]
        )

        let configuration = ModalCardPresentationConfiguration(
            contentAppearanceAnimator: appearanceAnimator,
            contentDissmisalAnimator: dismissalAnimator,
            style: ModalCardPresentationStyle.defaultStyle,
            extendUnderSafeArea: true,
            dismissFinishSpeedFactor: 0.6,
            dismissCancelSpeedFactor: 0.6
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
