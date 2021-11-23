import UIKit

extension NSAttributedString {
    static func crowdloanTerms(for locale: Locale?) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorLightGray()!,
            .font: UIFont.p2Paragraph
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorNovaBlue()!
        ]

        let termsConditions = R.string.localizable.crowdloanTermsValue(preferredLanguages: locale?.rLanguages)
        let termDecorator = HighlightingAttributedStringDecorator(
            pattern: termsConditions,
            attributes: highlightAttributes
        )

        let resultString = R.string.localizable
            .crowdloanTermsFormat(termsConditions, preferredLanguages: locale?.rLanguages)

        return CompoundAttributedStringDecorator(
            decorators: [rangeDecorator, termDecorator]
        ).decorate(attributedString: NSAttributedString(string: resultString))
    }
}
