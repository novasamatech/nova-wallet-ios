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
        contentViewController(self)
    }

    private func contentViewController<T>(_ vc: UIViewController?) -> T? {
        guard let vc = vc else {
            return nil
        }

        if let tabBarController = vc as? UITabBarController {
            return contentViewController(tabBarController.selectedViewController)
        }
        if let navBarController = vc as? UINavigationController {
            return contentViewController(navBarController.topViewController)
        }

        return vc as? T
    }
}
