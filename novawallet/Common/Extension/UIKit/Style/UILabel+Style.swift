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

extension UILabel.Style {
    static let footnotePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularFootnote
    )

    static let footnoteSecondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .regularFootnote
    )

    static let caption1Secondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .caption1
    )

    static let regularSubhedlinePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularSubheadline
    )

    static let rowLink = UILabel.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .p2Paragraph
    )

    static let secondaryScreenTitle = UILabel.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldTitle2
    )
}
