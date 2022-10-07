import UIKit
import SoraUI

extension UILabel {
    struct Style {
        let textColor: UIColor?
        let font: UIFont
    }

    convenience init(style: Style, textAlignment: NSTextAlignment = .left, numberOfLines: Int = 0) {
        self.init()
        self.textAlignment = textAlignment
        self.numberOfLines = numberOfLines
        apply(style: style)
    }

    func apply(style: Style) {
        textColor = style.textColor
        font = style.font
    }
}

extension RoundedView {
    struct Style {
        let fillColor: UIColor
        let highlightedFillColor: UIColor
        let cornerRadius: CGFloat
    }

    func apply(style: Style) {
        fillColor = style.fillColor
        highlightedFillColor = style.highlightedFillColor
        cornerRadius = style.cornerRadius
    }
}
