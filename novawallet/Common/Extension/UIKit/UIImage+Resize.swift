import UIKit

extension UIImage {
    func resizableCenterImage() -> UIImage {
        let topBottomInset = (size.height - 1) / 2
        let leftRightInset = (size.width - 1) / 2
        let insets = UIEdgeInsets(
            top: topBottomInset,
            left: leftRightInset,
            bottom: topBottomInset,
            right: leftRightInset
        )

        return resizableImage(withCapInsets: insets)
    }
}
