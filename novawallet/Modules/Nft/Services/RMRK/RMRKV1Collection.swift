import Foundation

struct RMRKV1Collection: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case name
        case metadata
        case issuer
        case max
    }

    let identifier: String
    let name: String?
    let metadata: String?
    let issuer: String?
    let max: Int32?
}
