import UIKit

extension UIEdgeInsets {
    init(verticalInset: CGFloat = .zero, horizontalInset: CGFloat = .zero) {
        self.init(top: verticalInset, left: horizontalInset, bottom: verticalInset, right: horizontalInset)
    }

    init(inset: CGFloat) {
        self.init(top: inset, left: inset, bottom: inset, right: inset)
    }
}
