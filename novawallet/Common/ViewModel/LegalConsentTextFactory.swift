import UIKit

enum LegalConsentTextFactory {
    struct Link {
        let marker: String
        let type: LegalDocumentType
        let title: String
    }

    static func createAgreementText(for locale: Locale) -> NSAttributedString {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable
        let agreement = strings.legalConsentAgreement

        let links: [Link] = [
            Link(
                marker: Constants.termsMarker,
                type: .termsOfService,
                title: strings.commonTermsOfService.localizedOrDevelopmentValue()
            ),
            Link(
                marker: Constants.privacyMarker,
                type: .privacyNotice,
                title: strings.commonPrivacyNotice.localizedOrDevelopmentValue()
            )
        ]

        let templates = [
            agreement.localizedOrDevelopmentValue(Constants.termsMarker, Constants.privacyMarker),
            agreement.formattedDevelopmentValue(Constants.termsMarker, Constants.privacyMarker)
        ].compactMap { $0 }

        return createAgreementText(from: templates, links: links)
    }

    static func createAgreementText(from templates: [String], links: [Link]) -> NSAttributedString {
        for template in templates.map({ $0 as NSString }) {
            let placements = createPlacements(in: template, links: links)

            guard placements.count == links.count else {
                continue
            }

            return createAttributedString(from: template, placements: placements)
        }

        return createSalvagedString(from: (templates.first ?? "") as NSString, links: links)
    }
}

// MARK: - Private

private extension LegalConsentTextFactory {
    struct Placement {
        let range: NSRange
        let title: String
        let type: LegalDocumentType
    }

    static func createPlacements(in template: NSString, links: [Link]) -> [Placement] {
        links
            .compactMap { link -> Placement? in
                let range = template.range(of: link.marker)

                guard range.location != NSNotFound else {
                    return nil
                }

                return Placement(range: range, title: link.title, type: link.type)
            }
            .sorted { $0.range.location < $1.range.location }
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

    static func createSalvagedString(from template: NSString, links: [Link]) -> NSAttributedString {
        let placements = createPlacements(in: template, links: links)
        let placedTypes = Set(placements.map(\.type))

        let result = NSMutableAttributedString(
            attributedString: createAttributedString(from: template, placements: placements)
        )

        for link in links where !placedTypes.contains(link.type) {
            result.append(
                NSAttributedString(
                    string: Constants.appendedLinkSeparator,
                    attributes: baseAttributes()
                )
            )
            result.append(
                NSAttributedString(
                    string: link.title,
                    attributes: linkAttributes(for: link.type)
                )
            )
        }

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

        static let appendedLinkSeparator = " "
    }
}
