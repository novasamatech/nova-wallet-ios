import Foundation

struct RMRKNftV1: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case collectionId
        case name
        case instance
        case owner
        case forsale
        case metadata
    }

    let identifier: String
    let collectionId: String
    let name: String
    let instance: String
    let owner: String
    let forsale: Decimal?
    let metadata: String?
}

struct RMRKNftMetadataV1: Codable {
    enum CodingKeys: String, CodingKey {
        case externalUrl = "external_url"
        case image
        case description
        case name
        case backgroundColor = "background_color"
        case animationUrl = "animation_url"
    }

    let externalUrl: String?
    let image: String?
    let description: String?
    let name: String?
    let backgroundColor: String?
    let animationUrl: String?
}
