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

    static let semiboldSubhedlineSecondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .semiBoldSubheadline
    )

    static let semiboldSubhedlinePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldSubheadline
    )

    static let semiboldBodyPrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldBody
    )

    static let semiboldChip = UILabel.Style(
        textColor: R.color.colorChipText(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnotePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnotePositive = UILabel.Style(
        textColor: R.color.colorTextPositive(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnoteButtonInactive = UILabel.Style(
        textColor: R.color.colorButtonTextInactive(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnoteButtonText = UILabel.Style(
        textColor: R.color.colorButtonText(),
        font: .semiBoldFootnote
    )

    static let semiboldCalloutPositive = UILabel.Style(
        textColor: R.color.colorTextPositive(),
        font: .semiBoldCallout
    )

    static let footnoteIconChip = UILabel.Style(
        textColor: R.color.colorIconChip(),
        font: .regularFootnote
    )

    static let footnoteAccentText = UILabel.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .regularFootnote
    )

    static let caption1Primary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .caption1
    )

    static let caption1Secondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .caption1
    )

    static let caption1Tertiary = UILabel.Style(
        textColor: R.color.colorTextTertiary(),
        font: .caption1
    )

    static let caption1Positive = UILabel.Style(
        textColor: R.color.colorTextPositive(),
        font: .caption1
    )

    static let caption1Negative = UILabel.Style(
        textColor: R.color.colorTextNegative(),
        font: .caption1
    )

    static let caption2Secondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .caption2
    )

    static let semiboldCaps2Secondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .semiBoldCaps2
    )

    static let regularSubhedlinePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularSubheadline
    )

    static let regularSubhedlineInactive = UILabel.Style(
        textColor: R.color.colorIconInactive(),
        font: .regularSubheadline
    )

    static let regularSubhedlineSecondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
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

    static let bottomSheetTitle = UILabel.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .semiBoldBody
    )

    static let title3Primary = UILabel.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .semiBoldTitle3
    )

    static let title3Secondary = UILabel.Style(
        textColor: R.color.colorTextSecondary()!,
        font: .semiBoldTitle3
    )

    static let boldTitle2Primary = UILabel.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldTitle2
    )

    static let sourceCodePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .regularFootnote
    )

    static let boldLargePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldLargeTitle
    )
}
