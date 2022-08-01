import UIKit

extension CompoundAttributedStringDecorator {
    static func legal(for locale: Locale?) -> AttributedStringDecoratorProtocol {
        let textColor = R.color.colorWhite48()!
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: UIFont.regularFootnote
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite()!,
            .font: UIFont.regularFootnote
        ]

        let termsConditions = R.string.localizable
            .onboardingTermsAndConditions2(preferredLanguages: locale?.rLanguages)
        let termDecorator = HighlightingAttributedStringDecorator(
            pattern: termsConditions,
            attributes: highlightAttributes
        )

        let privacyPolicy = R.string.localizable
            .onboardingPrivacyPolicy(preferredLanguages: locale?.rLanguages)
        let privacyDecorator = HighlightingAttributedStringDecorator(
            pattern: privacyPolicy,
            attributes: highlightAttributes
        )

        return CompoundAttributedStringDecorator(decorators: [rangeDecorator, termDecorator, privacyDecorator])
    }
}
