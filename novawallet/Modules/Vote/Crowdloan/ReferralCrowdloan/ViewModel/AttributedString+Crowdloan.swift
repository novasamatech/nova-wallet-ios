import UIKit

extension NSAttributedString {
    static func crowdloanTerms(for locale: Locale?) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextSecondary()!,
            .font: UIFont.p2Paragraph
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorButtonTextAccent()!
        ]

        let termsConditions = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanTermsValue()
        let termDecorator = HighlightingAttributedStringDecorator(
            pattern: termsConditions,
            attributes: highlightAttributes
        )

        let resultString = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.crowdloanTermsFormat(termsConditions)

        return CompoundAttributedStringDecorator(
            decorators: [rangeDecorator, termDecorator]
        ).decorate(attributedString: NSAttributedString(string: resultString))
    }
}
