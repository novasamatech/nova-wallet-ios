import UIKit

extension CompoundAttributedStringDecorator {
    static func legal(for locale: Locale?, marker: String) -> AttributedStringDecoratorProtocol {
        let textColor = R.color.colorTextSecondary()!
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: UIFont.regularFootnote
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextPrimary()!,
            .font: UIFont.regularFootnote
        ]

        let termsConditions = R.string.localizable
            .commonTermsAndConditions(preferredLanguages: locale?.rLanguages)

        let privacyPolicy = R.string.localizable
            .commonPrivacyPolicy(preferredLanguages: locale?.rLanguages)

        let replacementDecorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [termsConditions, privacyPolicy],
            attributes: highlightAttributes
        )

        return CompoundAttributedStringDecorator(decorators: [rangeDecorator, replacementDecorator])
    }
}
