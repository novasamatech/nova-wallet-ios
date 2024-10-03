import Foundation

enum SwipeGovSummary {
    enum Api {
        static let listPath = "/not-secure/api/v1/referendum-summaries/list"
    }

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
