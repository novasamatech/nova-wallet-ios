import Foundation

enum LegalDocumentType: String, CaseIterable {
    case termsOfService = "TERMS_OF_SERVICE"
    case privacyNotice = "PRIVACY_NOTICE"
}

extension LegalDocumentType {
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

    let version: Int

    let updatedAt: Date
}
