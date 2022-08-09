import Foundation

struct Currency: Codable, Equatable {
    let id: Int
    let code: String
    let name: String
    let symbol: String?
    let category: Category
    let isPopular: Bool
    let coingeckoId: String

    enum CodingKeys: String, CodingKey {
        case id
        case code
        case name
        case symbol
        case category
        case isPopular = "popular"
        case coingeckoId
    }
}

extension Currency {
    enum Category: String, Codable {
        case fiat
        case crypto
    }
}
