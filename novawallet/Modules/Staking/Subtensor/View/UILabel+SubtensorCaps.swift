import UIKit

extension UILabel {
    func applySubtensorCaps(_ text: String) {
        apply(text: text, lineHeight: SubtensorCapsConstants.lineHeight, kern: SubtensorCapsConstants.kern)
    }
}

private enum SubtensorCapsConstants {
    static let lineHeight: CGFloat = 13
    static let kern: CGFloat = 0.6
}
