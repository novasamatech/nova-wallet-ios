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

        let termsConditions = R.string(preferredLanguages: locale.rLanguages).localizable
            .commonTermsAndConditions()

        let privacyPolicy = R.string(preferredLanguages: locale.rLanguages).localizable
            .commonPrivacyPolicy()

        let replacementDecorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [termsConditions, privacyPolicy],
            attributes: highlightAttributes
        )

        return CompoundAttributedStringDecorator(decorators: [rangeDecorator, replacementDecorator])
    }

    /// Decorator for the mandatory consent banner on wallet creation/import flows.
    /// Uses dedicated strings ("Terms of Service" / "Privacy Notice") per Aurum's
    /// verbatim wording requirement. Underlined link spans match the standard
    /// hyperlink visual treatment required by the lawyer.
    static func consentBanner(for locale: Locale?, marker: String) -> AttributedStringDecoratorProtocol {
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextSecondary()!,
            .font: UIFont.regularFootnote
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: bodyAttributes)

        let linkAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorTextPrimary()!,
            .font: UIFont.regularFootnote,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let termsOfService = R.string(preferredLanguages: locale.rLanguages).localizable
            .consentBannerTermsOfService()

        let privacyNotice = R.string(preferredLanguages: locale.rLanguages).localizable
            .consentBannerPrivacyNotice()

        let replacementDecorator = AttributedReplacementStringDecorator(
            pattern: marker,
            replacements: [termsOfService, privacyNotice],
            attributes: linkAttributes
        )

        return CompoundAttributedStringDecorator(decorators: [rangeDecorator, replacementDecorator])
    }
}
