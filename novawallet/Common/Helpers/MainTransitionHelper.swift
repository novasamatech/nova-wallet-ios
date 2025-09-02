import UIKit
import UIKit_iOS

enum MainTransitionPostProcessing {
    case flowStatus(FlowStatusPresentingClosure)
    case postTransition((MainTabBarViewController) -> Void)
    case nothing
}

enum MainTransitionHelper {
    static func transitToMainTabBarController(
        selectingIndex: Int = MainTabBarViewFactory.walletIndex,
        closing controller: UIViewController,
        flowStatusClosure: FlowStatusPresentingClosure? = nil,
        animated: Bool
    ) {
        let postProcessing = if let flowStatusClosure {
            MainTransitionPostProcessing.flowStatus(flowStatusClosure)
        } else {
            MainTransitionPostProcessing.nothing
        }

        transitToMainTabBarController(
            selectingIndex: selectingIndex,
            closing: controller,
            postProcessing: postProcessing,
            animated: animated
        )
    }

    static func transitToMainTabBarController(
        selectingIndex: Int = MainTabBarViewFactory.walletIndex,
        closing controller: UIViewController,
        postProcessing: MainTransitionPostProcessing,
        animated: Bool
    ) {
        if let presentingController = controller.presentingViewController {
            presentingController.dismiss(animated: animated, completion: nil)
        }

        guard let tabBarController = UIApplication.shared.tabBarController else {
            return
        }

        let postProcessingClosure = {
            switch postProcessing {
            case let .flowStatus(closure):
                tabBarController.presentStatusAlert(closure)
            case let .postTransition(closure):
                closure(tabBarController)
            case .nothing:
                break
            }
        }

        let navigationController = tabBarController.selectedViewController as? UINavigationController

        guard tabBarController.selectedIndex != selectingIndex else {
            navigationController?.popToRootViewController(animated: animated)
            postProcessingClosure()

            return
        }

        navigationController?.popToRootViewController(animated: false)

        tabBarController.selectedIndex = selectingIndex

        if animated {
            TransitionAnimator(type: .reveal).animate(view: tabBarController.view, completionBlock: nil)
        }

        postProcessingClosure()
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
