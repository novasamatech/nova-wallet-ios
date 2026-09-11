import XCTest
@testable import novawallet

final class AnalyticsConsentPromptTests: XCTestCase {
    func testPromptShownOnAFreshConsentedInstall() {
        assertPromptShown(true)
    }

    func testNoPromptWithoutAWallet() {
        assertPromptShown(false, hasWallet: false)
    }

    func testNoPromptWhenAlreadySeen() {
        assertPromptShown(false, promptSeen: true)
    }

    func testNoPromptWhenLegalConsentIsStillRequired() {
        assertPromptShown(false, legalStatus: .required)
    }

    private func assertPromptShown(_ expected: Bool, hasWallet: Bool = true, promptSeen: Bool = false, legalStatus: LegalConsentStatus = .notRequired, line: UInt = #line) {
        let isPossible = AnalyticsConsentPromptGate.isPossible(hasWallet: hasWallet, isPromptSeen: promptSeen, isAvailable: true, isEnabled: false, didPresentLegalConsentThisLaunch: false)

        XCTAssertEqual(isPossible && AnalyticsConsentPromptGate.allows(legalStatus: legalStatus), expected, line: line)
    }
}
