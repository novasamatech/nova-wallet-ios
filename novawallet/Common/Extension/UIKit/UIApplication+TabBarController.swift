import UIKit

extension UIApplication {
    var tabBarController: MainTabBarViewController? {
        delegate?
            .window??
            .rootViewController?
            .children
            .first(where: { $0 is UITabBarController }) as? MainTabBarViewController
    }
}
