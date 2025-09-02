import Foundation

struct MercuryoGenericResponse<R: Decodable>: Decodable {
    let status: Int
    let data: R?
}

struct MercuryoCard: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case number = "card_number"
        case issuedByMercuryo = "issued_by_mercuryo"
    }

    let id: String
    let createdAt: String
    let number: String
    let issuedByMercuryo: Bool
}
