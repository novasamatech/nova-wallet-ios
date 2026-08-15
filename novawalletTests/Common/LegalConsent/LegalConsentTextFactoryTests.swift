import XCTest
@testable import novawallet

final class LegalConsentTextFactoryTests: XCTestCase {
    private let factory = LegalConsentTextFactory()

    // MARK: - Agreement

    func testAgreementRendersMarkersFromAnIntactTemplate() {
        let agreement = factory.createAgreementText(
            from: "I agree to the {TOS} and acknowledge the {PN}." as NSString,
            links: [
                LegalConsentTextFactory.Link(marker: "{TOS}", url: Constants.termsURL, title: "Terms"),
                LegalConsentTextFactory.Link(marker: "{PN}", url: Constants.privacyURL, title: "Privacy")
            ]
        )

        XCTAssertEqual(agreement.string, "I agree to the Terms and acknowledge the Privacy.")
        XCTAssertEqual(linkedURLs(in: agreement), Constants.bothURLs)
    }
}

private extension LegalConsentTextFactoryTests {
    enum Constants {
        static let termsURL = URL(string: "https://novawallet.io/terms")!
        static let privacyURL = URL(string: "https://novawallet.io/privacy")!

        static let bothURLs: Set<URL> = [termsURL, privacyURL]
    }

    func linkedURLs(in text: NSAttributedString) -> Set<URL> {
        var urls: Set<URL> = []

        text.enumerateAttribute(
            .link,
            in: NSRange(location: 0, length: text.length)
        ) { value, _, _ in
            guard let url = value as? URL else {
                return
            }

            urls.insert(url)
        }

        return urls
    }
}
