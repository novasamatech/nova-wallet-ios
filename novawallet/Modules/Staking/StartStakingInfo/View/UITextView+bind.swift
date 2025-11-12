import UIKit
import Foundation

extension UITextView {
    func bind(
        url: URL,
        urlText: String,
        in text: String,
        style: UITextView.Style,
        showsLinkChevron: Bool = true,
        linkFont: UIFont? = nil
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: style.font,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: style.textColor
            ]
        )

        if let range = text.range(of: urlText) {
            let linkFont = linkFont ?? style.font

            let nsRange = NSRange(range, in: text)
            var nsRangeLength = nsRange.length

            if showsLinkChevron {
                let attachment = createChevronAttachment(font: linkFont)

                attributedString.append(attachment)
                nsRangeLength += 1
            }

            attributedString.addAttribute(
                .foregroundColor,
                value: R.color.colorTextLink()!,
                range: NSRange(location: nsRange.location, length: nsRangeLength)
            )
            attributedString.addAttributes(
                [.font: linkFont, .link: url],
                range: nsRange
            )
        }

        attributedText = attributedString
    }

    private func createChevronAttachment(font: UIFont) -> NSAttributedString {
        let size = CGSize(width: font.lineHeight, height: font.lineHeight)
        let imageAttachment = NSTextAttachment()
        imageAttachment.image = R.image.iconLinkChevron()!

        let centerImageY = 2 * font.descender - size.height / 2 + font.capHeight
        imageAttachment.bounds = CGRect(origin: .init(x: 0, y: centerImageY), size: size)

        return NSAttributedString(attachment: imageAttachment)
    }
}

extension UITextView {
    struct Style {
        let textColor: UIColor?
        let font: UIFont
    }

    convenience init(style: Style, textAlignment: NSTextAlignment = .left) {
        self.init()
        self.textAlignment = textAlignment

        apply(style: style)
    }

    func apply(style: Style) {
        textColor = style.textColor
        font = style.font
    }
}

extension UITextView.Style {
    static let footnotePrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularFootnote
    )

    static let footnoteSecondary = UITextView.Style(
        textColor: R.color.colorTextSecondary(),
        font: .regularFootnote
    )

    static let footnoteSecondaryOnWhite = UITextView.Style(
        textColor: R.color.colorTextSecondaryOnWhite(),
        font: .regularFootnote
    )

    static let semiboldSubhedlineSecondary = UITextView.Style(
        textColor: R.color.colorTextSecondary(),
        font: .semiBoldSubheadline
    )

    static let semiboldSubhedlinePrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldSubheadline
    )

    static let semiboldSubheadlineAccent = UITextView.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .semiBoldSubheadline
    )

    static let semiboldBodyButtonAccent = UITextView.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .semiBoldBody
    )

    static let semiboldBodyPrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldBody
    )

    static let semiboldBodySecondary = UITextView.Style(
        textColor: R.color.colorTextSecondary(),
        font: .semiBoldBody
    )

    static let semiboldChip = UITextView.Style(
        textColor: R.color.colorChipText(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnotePrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnotePositive = UITextView.Style(
        textColor: R.color.colorTextPositive(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnoteButtonInactive = UITextView.Style(
        textColor: R.color.colorButtonTextInactive(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnoteButtonText = UITextView.Style(
        textColor: R.color.colorButtonText(),
        font: .semiBoldFootnote
    )

    static let semiboldFootnoteAccentText = UITextView.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .semiBoldFootnote
    )

    static let semiboldCalloutPrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldCallout
    )

    static let semiboldCalloutPositive = UITextView.Style(
        textColor: R.color.colorTextPositive(),
        font: .semiBoldCallout
    )

    static let footnoteIconChip = UITextView.Style(
        textColor: R.color.colorIconChip(),
        font: .regularFootnote
    )

    static let footnoteAccentText = UITextView.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .regularFootnote
    )

    static let semiboldCaption1Primary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldCaption1
    )

    static let caption1Primary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .caption1
    )

    static let caption1Secondary = UITextView.Style(
        textColor: R.color.colorTextSecondary(),
        font: .caption1
    )

    static let caption1Accent = UITextView.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .caption1
    )

    static let caption1Positive = UITextView.Style(
        textColor: R.color.colorTextPositive(),
        font: .caption1
    )

    static let caption1Negative = UITextView.Style(
        textColor: R.color.colorTextNegative(),
        font: .caption1
    )

    static let caption2Secondary = UITextView.Style(
        textColor: R.color.colorTextSecondary(),
        font: .caption2
    )

    static let semiboldCaps2Primary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .semiBoldCaps2
    )

    static let semiboldCaps2Positive = UITextView.Style(
        textColor: R.color.colorTextPositive(),
        font: .semiBoldCaps2
    )

    static let semiboldCaps1ChipText = UITextView.Style(
        textColor: R.color.colorChipText(),
        font: .semiBoldCaps1
    )

    static let semiboldCaps2Secondary = UITextView.Style(
        textColor: R.color.colorTextSecondary(),
        font: .semiBoldCaps2
    )

    static let semiboldCaps2Inactive = UITextView.Style(
        textColor: R.color.colorButtonTextInactive(),
        font: .semiBoldCaps2
    )

    static let regularSubhedlinePrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularSubheadline
    )

    static let regularSubhedlinePrimaryOnWhite = UITextView.Style(
        textColor: R.color.colorTextPrimaryOnWhite(),
        font: .regularSubheadline
    )

    static let regularSubhedlineInactive = UITextView.Style(
        textColor: R.color.colorIconInactive(),
        font: .regularSubheadline
    )

    static let regularSubhedlineSecondary = UITextView.Style(
        textColor: R.color.colorTextSecondary(),
        font: .regularSubheadline
    )

    static let regularSubhedlineAccent = UITextView.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .regularSubheadline
    )

    static let rowLink = UITextView.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .p2Paragraph
    )

    static let secondaryScreenTitle = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldTitle3
    )

    static let bottomSheetTitle = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .semiBoldBody
    )

    static let title3Primary = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .semiBoldTitle3
    )

    static let title3Secondary = UITextView.Style(
        textColor: R.color.colorTextSecondary()!,
        font: .semiBoldTitle3
    )

    static let boldTitle1Primary = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldTitle1
    )

    static let boldTitle1Positive = UITextView.Style(
        textColor: R.color.colorTextPositive()!,
        font: .boldTitle1
    )

    static let boldTitle1Negative = UITextView.Style(
        textColor: R.color.colorTextNegative()!,
        font: .boldTitle1
    )

    static let boldTitle2Primary = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldTitle2
    )

    static let boldTitle3Primary = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldTitle3
    )

    static let boldTitle3Warning = UITextView.Style(
        textColor: R.color.colorTextWarning()!,
        font: .boldTitle3
    )

    static let sourceCodePrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .regularFootnote
    )

    static let boldLargePrimary = UITextView.Style(
        textColor: R.color.colorTextPrimary()!,
        font: .boldLargeTitle
    )

    static let regularCalloutSecondary = UITextView.Style(
        textColor: R.color.colorTextSecondary()!,
        font: .regularCallout
    )

    static let semiboldCalloutSecondary = UITextView.Style(
        textColor: R.color.colorTextSecondary()!,
        font: .semiBoldCallout
    )
}
