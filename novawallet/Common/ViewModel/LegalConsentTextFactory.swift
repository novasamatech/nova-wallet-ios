import UIKit

/// Builds the single consent sentence shared by the welcome screen and the legal consent sheet,
/// with the document names underlined and independently tappable.
///
/// Each link is resolved by its own marker rather than by split index, so a translation is free to
/// reorder `%1$@` and `%2$@` without the Terms label landing on the Privacy link.
///
/// `CompoundAttributedStringDecorator.legal(for:marker:)` is deliberately left untouched so
/// `NotificationsSetupViewController` keeps rendering as it does today.
enum LegalConsentTextFactory {
    static func createAgreementText(for locale: Locale) -> NSAttributedString {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let template = strings.legalConsentAgreement(
            Constants.termsMarker,
            Constants.privacyMarker
        ) as NSString

        let links: [(marker: String, type: LegalDocumentType, title: String)] = [
            (Constants.termsMarker, .termsOfService, strings.commonTermsOfService()),
            (Constants.privacyMarker, .privacyNotice, strings.commonPrivacyNotice())
        ]

        let placements = links
            .compactMap { link -> Placement? in
                let range = template.range(of: link.marker)

                guard range.location != NSNotFound else {
                    return nil
                }

                return Placement(range: range, title: link.title, type: link.type)
            }
            .sorted { $0.range.location < $1.range.location }

        return createAttributedString(from: template, placements: placements)
    }
}

// MARK: - Private

private extension LegalConsentTextFactory {
    struct Placement {
        let range: NSRange
        let title: String
        let type: LegalDocumentType
    }

    static func createAttributedString(
        from template: NSString,
        placements: [Placement]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        var cursor = 0

        for placement in placements {
            let plainRange = NSRange(
                location: cursor,
                length: placement.range.location - cursor
            )

            result.append(
                NSAttributedString(
                    string: template.substring(with: plainRange),
                    attributes: baseAttributes()
                )
            )
            result.append(
                NSAttributedString(
                    string: placement.title,
                    attributes: linkAttributes(for: placement.type)
                )
            )

            cursor = placement.range.location + placement.range.length
        }

        result.append(
            NSAttributedString(
                string: template.substring(from: cursor),
                attributes: baseAttributes()
            )
        )

        return result
    }

    static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: Constants.style.font,
            .foregroundColor: R.color.colorTextSecondary()!
        ]
    }

    static func linkAttributes(for type: LegalDocumentType) -> [NSAttributedString.Key: Any] {
        let linkColor = R.color.colorTextPrimary()!

        return [
            .font: Constants.style.font,
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: linkColor,
            .link: type.linkURL
        ]
    }
}

// MARK: - Constants

private extension LegalConsentTextFactory {
    enum Constants {
        static let style: UITextView.Style = .regularSubhedlineSecondary

        static let termsMarker = "{TOS}"
        static let privacyMarker = "{PN}"
    }
}
