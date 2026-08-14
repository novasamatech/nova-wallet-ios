import Foundation

/// Raw values are persisted inside `SettingsManagerProtocol.legalConsentAcceptedVersions` and match
/// the remote config keys. Renaming a case silently resets every user's accepted version and
/// re-prompts the whole installed base.
enum LegalDocumentType: String, CaseIterable {
    case termsOfService = "TERMS_OF_SERVICE"
    case privacyNotice = "PRIVACY_NOTICE"
}

extension LegalDocumentType {
    /// Sentinel carried in the `.link` attribute of the consent sentence and mapped back to a type
    /// by the view. It is never opened: the scheme is not registered by the app, so even a stray
    /// external open is inert, and the real document URLs stay out of the view layer.
    var linkURL: URL {
        switch self {
        case .termsOfService:
            URL(string: "novalegal://terms")!
        case .privacyNotice:
            URL(string: "novalegal://privacy")!
        }
    }

    static func fromLinkURL(_ url: URL) -> LegalDocumentType? {
        allCases.first { $0.linkURL == url }
    }
}

struct LegalDocument: Equatable {
    let type: LegalDocumentType

    /// Compared with strict `<`: an equal or downgraded remote version never prompts.
    let version: Int

    /// Never displayed — it exists only as a config validity gate, so a malformed value
    /// invalidates the whole config.
    let updatedAt: Date
}
