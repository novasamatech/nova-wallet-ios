import UIKit

protocol LegalConsentTextFactoryProtocol {
    func createAgreementText(
        for locale: Locale,
        termsURL: URL,
        privacyURL: URL
    ) -> NSAttributedString
}

// swiftformat:disable:next enumNamespaces
final class LegalConsentTextFactory {
    struct Link {
        let marker: String
        let url: URL
        let title: String
    }
}

// MARK: - LegalConsentTextFactoryProtocol

extension LegalConsentTextFactory: LegalConsentTextFactoryProtocol {
    func createAgreementText(
        for locale: Locale,
        termsURL: URL,
        privacyURL: URL
    ) -> NSAttributedString {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let links: [Link] = [
            Link(
                marker: Constants.termsMarker,
                url: termsURL,
                title: strings.commonTermsOfService()
            ),
            Link(
                marker: Constants.privacyMarker,
                url: privacyURL,
                title: strings.commonPrivacyNotice()
            )
        ]

        let template = strings.legalConsentAgreement(
            Constants.termsMarker,
            Constants.privacyMarker
        ) as NSString

        return createAgreementText(from: template, links: links)
    }

    func createAgreementText(from template: NSString, links: [Link]) -> NSAttributedString {
        createAttributedString(
            from: template,
            placements: createPlacements(in: template, links: links)
        )
    }
}

// MARK: - Private

private extension LegalConsentTextFactory {
    struct Placement {
        let range: NSRange
        let title: String
        let url: URL
    }

    func createPlacements(in template: NSString, links: [Link]) -> [Placement] {
        links
            .compactMap { link -> Placement? in
                let range = template.range(of: link.marker)

                guard range.location != NSNotFound else {
                    return nil
                }

                return Placement(range: range, title: link.title, url: link.url)
            }
            .sorted { $0.range.location < $1.range.location }
    }

    func createAttributedString(
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
                    attributes: linkAttributes(for: placement.url)
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

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: Constants.style.font,
            .foregroundColor: R.color.colorTextSecondary()!
        ]
    }

    func linkAttributes(for url: URL) -> [NSAttributedString.Key: Any] {
        let linkColor = R.color.colorTextPrimary()!

        return [
            .font: Constants.style.font,
            .foregroundColor: linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: linkColor,
            .link: url
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
