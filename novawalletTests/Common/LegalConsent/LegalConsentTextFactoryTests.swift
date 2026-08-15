import XCTest
@testable import novawallet

final class LegalConsentTextFactoryTests: XCTestCase {
    private lazy var supportedLanguages: [String] = Bundle(for: LegalConsentRepository.self)
        .localizations
        .filter { $0 != "Base" }

    // MARK: - Fallback

    func testUntranslatedConsentKeysFallBackToEnglish() {
        for language in supportedLanguages {
            let strings = R.string(preferredLanguages: [language]).localizable

            let values = [
                strings.legalConsentTitle,
                strings.legalConsentSubtitle,
                strings.legalConsentAccept,
                strings.commonTermsOfService,
                strings.commonPrivacyNotice
            ].map { ($0.key.description, $0.localizedOrDevelopmentValue()) }

            for (key, value) in values {
                XCTAssertNotEqual(value, key, "\(language) renders the raw key \(key)")
                XCTAssertFalse(value.isEmpty, "\(language) renders an empty string for \(key)")
            }
        }
    }

    func testTranslatedKeyKeepsSelectedLanguage() {
        let resource = R.string(preferredLanguages: ["ru"]).localizable.commonCancel

        XCTAssertNotEqual(resource.localizedOrDevelopmentValue(), resource.developmentValue ?? "")
    }

    // MARK: - Agreement

    func testAgreementCarriesBothLinksInEveryLanguage() {
        for language in supportedLanguages {
            let agreement = LegalConsentTextFactory.createAgreementText(
                for: Locale(identifier: language)
            )

            XCTAssertEqual(
                linkedTypes(in: agreement),
                Set(LegalDocumentType.allCases),
                "\(language) misses a legal document link"
            )

            let text = agreement.string

            XCTAssertFalse(
                text.contains("legal.consent") || text.contains("common.terms"),
                "\(language) renders a raw key: \(text)"
            )
            XCTAssertFalse(text.contains("{"), "\(language) leaves a marker in place: \(text)")
        }
    }

    func testAgreementAppendsLinksMissingFromTemplate() {
        let links = [
            LegalConsentTextFactory.Link(
                marker: "{TOS}",
                type: .termsOfService,
                title: "Terms of Service"
            ),
            LegalConsentTextFactory.Link(
                marker: "{PN}",
                type: .privacyNotice,
                title: "Privacy Notice"
            )
        ]

        let agreement = LegalConsentTextFactory.createAgreementText(
            from: ["I agree to the terms and acknowledge the notice."],
            links: links
        )

        XCTAssertEqual(linkedTypes(in: agreement), Set(LegalDocumentType.allCases))

        for link in links {
            XCTAssertTrue(agreement.string.contains(link.title))
        }
    }

    func testAgreementPrefersFirstIntactTemplate() {
        let links = [
            LegalConsentTextFactory.Link(marker: "{TOS}", type: .termsOfService, title: "Terms"),
            LegalConsentTextFactory.Link(marker: "{PN}", type: .privacyNotice, title: "Privacy")
        ]

        let agreement = LegalConsentTextFactory.createAgreementText(
            from: ["Selected {TOS} and {PN}.", "English {TOS} and {PN}."],
            links: links
        )

        XCTAssertEqual(agreement.string, "Selected Terms and Privacy.")
    }

    func testAgreementFallsThroughToIntactCandidate() {
        let links = [
            LegalConsentTextFactory.Link(marker: "{TOS}", type: .termsOfService, title: "Terms"),
            LegalConsentTextFactory.Link(marker: "{PN}", type: .privacyNotice, title: "Privacy")
        ]

        let agreement = LegalConsentTextFactory.createAgreementText(
            from: ["Selected {TOS}.", "English {TOS} and {PN}."],
            links: links
        )

        XCTAssertEqual(agreement.string, "English Terms and Privacy.")
        XCTAssertEqual(linkedTypes(in: agreement), Set(LegalDocumentType.allCases))
    }
}

// MARK: - Private

private extension LegalConsentTextFactoryTests {
    func linkedTypes(in text: NSAttributedString) -> Set<LegalDocumentType> {
        var types: Set<LegalDocumentType> = []

        text.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: text.length)
        ) { value, _, _ in
            guard
                let url = value as? URL,
                let type = LegalDocumentType.fromLinkURL(url)
            else {
                return
            }

            types.insert(type)
        }

        return types
    }
}
