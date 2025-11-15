import UIKit

extension UIBarButtonItem {
    func applyNoLiquidGlassStyle() {
        if #available(iOS 26.0, *) {
            sharesBackground = false
            hidesSharedBackground = true
        }
    }
}
