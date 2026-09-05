import Foundation

/// Split so both halves are pure and testable without a `MainTabBarInteractor` fixture.
/// `isPossible` covers the locally known conditions and runs first so a launch that cannot
/// prompt never issues the legal-documents fetch; `allows` covers the fetched tri-state.
/// There is no third place the conjunction is written.
enum AnalyticsConsentPromptGate {
    static func isPossible(
        hasWallet: Bool,
        isPromptSeen: Bool,
        isAvailable: Bool,
        isEnabled: Bool,
        didPresentLegalConsentThisLaunch: Bool
    ) -> Bool {
        hasWallet
            && !isPromptSeen
            && isAvailable
            && !isEnabled
            && !didPresentLegalConsentThisLaunch
    }

    /// `.unavailable` means the documents fetch failed, which `consentRequiredWrapper()` would
    /// have reported as "not required". Suppressing the prompt keeps a network blip from
    /// showing it on a launch where the legal sheet should have come first.
    static func allows(legalStatus: LegalConsentStatus) -> Bool {
        switch legalStatus {
        case .notRequired:
            true
        case .required, .unavailable:
            false
        }
    }
}
