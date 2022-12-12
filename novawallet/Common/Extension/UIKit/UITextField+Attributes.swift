import UIKit

extension UITextField {
    func applyLineBreakMode(_ lineBreakMode: NSLineBreakMode) {
        var attributes = defaultTextAttributes
        let currentStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        let paragraphStyle = (currentStyle?.mutableCopy() as? NSMutableParagraphStyle) ??
            NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = lineBreakMode
        attributes[.paragraphStyle] = paragraphStyle

        defaultTextAttributes = attributes
    }
}
