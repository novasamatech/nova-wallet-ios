import Foundation

struct RaiseCardAttributes: Decodable {
    struct CardValue: Decodable {
        let value: String?
        let raw: String
    }

    enum CodingKeys: String, CodingKey {
        case brandId = "brand_id"
        case number
        case pin = "csc"
        case url
        case expiresAt = "expires_at"
        case balance
        case currency
    }

    let brandId: String
    let number: CardValue?
    let pin: CardValue?
    let url: CardValue?
    let balance: RaiseBalance
    @ISO8601Codable var expiresAt: Date?
    let currency: String
}

struct RaiseCardsResponse: Decodable {
    let data: [RaiseResponseContent<RaiseCardAttributes>]
    let included: [RaiseResponseContent<RaiseBrandAttributes>]?
}

final class RaiseCardsResultFactory: BaseRaiseResultFactory<RaiseCardsResponse> {
    override func parseReponse(from data: Data) throws -> RaiseCardsResponse {
        try JSONDecoder().decode(
            RaiseCardsResponse.self,
            from: data
        )
    }
}
