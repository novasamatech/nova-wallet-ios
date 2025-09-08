import UIKit

extension UIBarButtonItem {
    func applyLiquidGlassStyle() {
        if #available(iOS 26.0, *) {
            sharesBackground = false
            hidesSharedBackground = true
        }
    }
}
