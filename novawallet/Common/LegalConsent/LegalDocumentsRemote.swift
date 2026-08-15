import Foundation

struct LegalDocumentsRemote: Decodable {
    let termsOfService: LegalDocumentRemote
    let privacyNotice: LegalDocumentRemote
}

struct LegalDocumentRemote: Decodable {
    let version: Int
    let updatedAt: LegalDocumentDate
}

struct LegalDocumentDate: Decodable, Equatable {
    let date: Date

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false

        return formatter
    }()

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard
            Self.hasExpectedShape(rawValue),
            let date = Self.formatter.date(from: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected updatedAt format: \(rawValue)"
            )
        }

        self.date = date
    }

    private static func hasExpectedShape(_ rawValue: String) -> Bool {
        guard rawValue.count == Constants.expectedLength else {
            return false
        }

        return rawValue.enumerated().allSatisfy { index, character in
            if Constants.separatorIndices.contains(index) {
                character == "-"
            } else {
                character.isASCII && character.isNumber
            }
        }
    }
}

// MARK: - Constants

private extension LegalDocumentDate {
    enum Constants {
        static let expectedLength: Int = 10
        static let separatorIndices: Set<Int> = [4, 7]
    }
}

// MARK: - Mapping

extension LegalDocumentsRemote {
    func mapToDocuments() -> [LegalDocument] {
        [
            LegalDocument(
                type: .termsOfService,
                version: termsOfService.version,
                updatedAt: termsOfService.updatedAt.date
            ),
            LegalDocument(
                type: .privacyNotice,
                version: privacyNotice.version,
                updatedAt: privacyNotice.updatedAt.date
            )
        ]
    }
}
