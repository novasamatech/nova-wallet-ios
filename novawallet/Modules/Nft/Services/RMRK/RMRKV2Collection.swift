import Foundation

struct RMRKV2Collection: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case symbol
        case max
        case metadata
        case issuer
    }

    let identifier: String
    let symbol: String?
    let max: Int32?
    let metadata: String?
    let issuer: String?
}
