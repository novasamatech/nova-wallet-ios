import UIKit
import UIKit_iOS

struct MainTransitionHelper {
    static func transitToMainTabBarController(
        selectingIndex: Int = MainTabBarViewFactory.walletIndex,
        closing controller: UIViewController,
        flowStatusClosure: FlowStatusPresentingClosure? = nil,
        animated: Bool
    ) {
        if let presentingController = controller.presentingViewController {
            presentingController.dismiss(animated: animated, completion: nil)
        }

        guard let tabBarController = UIApplication.shared.tabBarController else {
            return
        }

        let presentFlowStatusClosure = {
            guard let flowStatusClosure else { return }
            tabBarController.presentStatusAlert(flowStatusClosure)
        }

        let navigationController = tabBarController.selectedViewController as? UINavigationController

        guard tabBarController.selectedIndex != selectingIndex else {
            navigationController?.popToRootViewController(animated: animated)
            presentFlowStatusClosure()

            return
        }

        navigationController?.popToRootViewController(animated: false)

        tabBarController.selectedIndex = selectingIndex

        if animated {
            TransitionAnimator(type: .reveal).animate(view: tabBarController.view, completionBlock: nil)
        }

        presentFlowStatusClosure()
    }

    static func dismissAndPopBack(
        from view: ControllerBackedProtocol?,
        completion: ((UIViewController?) -> Void)? = nil
    ) {
        var rootNavigationController: UINavigationController?

        let presenter = view?.controller.navigationController?.presentingViewController

        if let tabBar = presenter as? UITabBarController {
            rootNavigationController = tabBar.selectedViewController as? UINavigationController
        } else {
            rootNavigationController = presenter as? UINavigationController
        }

        rootNavigationController?.popToRootViewController(animated: false)

        presenter?.dismiss(animated: true) {
            completion?(presenter)
        }
    }
}
