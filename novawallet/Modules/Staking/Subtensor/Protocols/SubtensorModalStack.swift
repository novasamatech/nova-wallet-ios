import UIKit

enum SubtensorModalStack {
    static func flowNavigation(
        above tabBarController: UITabBarController? = UIApplication.shared.tabBarController
    ) -> UINavigationController? {
        presentedController(by: tabBarController) as? UINavigationController
    }

    static func dismiss(
        above flowPresenter: UIViewController? = UIApplication.shared.tabBarController,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let overlayPresenter = flowPresenter?.parent
        let hasOverlay = presentsResult(overlayPresenter)

        let dismissOverlay = {
            guard let overlayPresenter, presentsResult(overlayPresenter) else {
                completion?()
                return
            }

            overlayPresenter.dismiss(animated: animated, completion: completion)
        }

        guard let flowPresenter, presentedController(by: flowPresenter) != nil else {
            dismissOverlay()
            return
        }

        flowPresenter.dismiss(animated: animated && !hasOverlay, completion: dismissOverlay)
    }
}

private extension SubtensorModalStack {
    static func presentedController(by presenter: UIViewController?) -> UIViewController? {
        guard
            let presenter,
            let presented = presenter.presentedViewController,
            presented.presentingViewController === presenter,
            !holdsAuthorization(from: presented) else {
            return nil
        }

        return presented
    }

    static func presentsResult(_ presenter: UIViewController?) -> Bool {
        presentedController(by: presenter) is SubtensorResultViewProtocol
    }

    static func holdsAuthorization(from controller: UIViewController) -> Bool {
        sequence(first: controller, next: { $0.presentedViewController }).contains { $0 is PinSetupViewProtocol }
    }
}
