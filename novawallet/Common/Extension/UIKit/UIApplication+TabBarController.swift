import UIKit

extension UIApplication {
    var tabBarController: MainTabBarViewController? {
        rootContainer?
            .children
            .first(where: { $0 is UITabBarController }) as? MainTabBarViewController
    }

    var rootContainer: NovaMainAppContainerViewController? {
        delegate?
            .window??
            .rootViewController as? NovaMainAppContainerViewController
    }
}
