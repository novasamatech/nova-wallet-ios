import Foundation

enum SwipeGovSummary {
    struct ListRequest: Encodable {
        let chainId: String
        let languageIsoCode: String
        let referendumIds: [String]
    }

    struct SingleResponse: Decodable {
        let chainId: String
        let languageIsoCode: String
        let referendumId: String
        let summary: String
    }

    typealias ListResponse = [SingleResponse]
}
