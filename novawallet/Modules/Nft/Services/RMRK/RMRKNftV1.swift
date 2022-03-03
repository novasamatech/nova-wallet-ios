import Foundation

struct RMRKNftV1: Codable {
    struct Collection: Codable {
        let max: Int32?
    }

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case collectionId
        case name
        case instance
        case serialNumber = "sn"
        case owner
        case forsale
        case metadata
        case collection
    }

    let identifier: String
    let collectionId: String
    let name: String
    let instance: String
    let serialNumber: String?
    let owner: String
    let forsale: Decimal?
    let metadata: String?
    let collection: Collection?
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
