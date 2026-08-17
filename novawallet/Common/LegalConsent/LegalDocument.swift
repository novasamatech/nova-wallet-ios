import Foundation

/// Raw values are persisted as settings keys: renaming a case re-prompts the whole installed base.
enum LegalDocumentType: String, CaseIterable {
    case termsOfService = "TERMS_OF_SERVICE"
    case privacyNotice = "PRIVACY_NOTICE"
}

struct LegalDocument: Equatable {
    let type: LegalDocumentType

    let version: Int

    /// Never displayed — parsed strictly so that a malformed value invalidates the whole config.
    let updatedAt: Date
}
