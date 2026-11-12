import UIKit
import UIKit_iOS

enum MainTransitionPostProcessing {
    case flowStatus(FlowStatusPresentingClosure)
    case postTransition((MainTabBarViewController) -> Void)
    case nothing
}

enum MainTransitionHelper {
    static func transitToMainTabBarController(
        selectingIndex: Int = MainTabBarIndex.wallet,
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
        selectingIndex: Int = MainTabBarIndex.wallet,
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

    static func dismissAllModals(
        from view: ControllerBackedProtocol?,
        completion: ((UIViewController?) -> Void)? = nil
    ) {
        guard let rootController = view?.controller.view.window?.rootViewController else {
            completion?(nil)
            return
        }

        var presenters: [UIViewController] = []

        if
            let tabBarModalsPresenter = UIApplication.shared.tabBarController?
            .presentedController()?
            .presentingViewController,
            tabBarModalsPresenter !== rootController {
            presenters.append(tabBarModalsPresenter)
        }

        presenters.append(rootController)

        dismissPresentations(
            of: presenters.filter { canDismissPresentation(of: $0) },
            animated: true
        ) {
            completion?(rootController)
        }
    }
}

private extension MainTransitionHelper {
    static func canDismissPresentation(of presenter: UIViewController) -> Bool {
        guard
            let presented = presenter.presentedViewController,
            presented.presentingViewController === presenter else {
            return false
        }

        // the pin screen of the app lock or of an ongoing authorization must stay on top
        return !sequence(first: presented, next: \.presentedViewController).contains { $0 is PinSetupViewProtocol }
    }

    static func dismissPresentations(
        of presenters: [UIViewController],
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        guard let presenter = presenters.first else {
            completion()
            return
        }

        let remainingPresenters = Array(presenters.dropFirst())

        presenter.dismiss(animated: animated && remainingPresenters.isEmpty) {
            dismissPresentations(of: remainingPresenters, animated: animated, completion: completion)
        }
    }
}
