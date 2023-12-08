import UIKit

extension UIViewController {
    var topModalViewController: UIViewController {
        var presentingController = self

        while let nextPresentingController = presentingController.presentedViewController {
            presentingController = nextPresentingController
        }

        return presentingController
    }

    func contentViewController<T>() -> T? {
        contentViewController(for: self)
    }

    private func contentViewController<T>(for viewController: UIViewController?) -> T? {
        guard let viewController = viewController else {
            return nil
        }

        if let tabBarController = viewController as? UITabBarController {
            return contentViewController(for: tabBarController.selectedViewController)
        }
        if let navBarController = viewController as? UINavigationController {
            return contentViewController(for: navBarController.topViewController)
        }

        return viewController as? T
    }
}
