import Foundation

struct RaiseRequest<A: Encodable>: Encodable {
    struct Content: Encodable {
        let type: String
        let attributes: A
    }

    let data: Content
}

struct RaiseIdentifiableRequest<A: Encodable>: Encodable {
    struct Content: Encodable {
        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case type
            case attributes
        }

        let identifier: String
        let type: String
        let attributes: A
    }

    let data: Content
}
