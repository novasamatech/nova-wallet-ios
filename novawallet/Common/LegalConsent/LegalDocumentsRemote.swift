import Foundation

struct LegalDocumentsRemote: Decodable {
    let termsOfService: LegalDocumentRemote
    let privacyNotice: LegalDocumentRemote
}

struct LegalDocumentRemote: Decodable {
    let version: Int

    @FullDateCodable var updatedAt: Date
}

// MARK: - Mapping

extension LegalDocumentsRemote {
    func mapToDocuments() -> [LegalDocument] {
        [
            LegalDocument(
                type: .termsOfService,
                version: termsOfService.version,
                updatedAt: termsOfService.updatedAt
            ),
            LegalDocument(
                type: .privacyNotice,
                version: privacyNotice.version,
                updatedAt: privacyNotice.updatedAt
            )
        ]
    }
}
