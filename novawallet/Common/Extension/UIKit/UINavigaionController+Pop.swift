import UIKit

extension UINavigationController {
    func findTopView<T>() -> T? {
        viewControllers.last(where: { $0 is T }) as? T
    }
}
