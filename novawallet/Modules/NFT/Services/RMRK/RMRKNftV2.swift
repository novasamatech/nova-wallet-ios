import Foundation

struct RMRKNftV2: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case collectionId
        case name = "metadata_name"
        case description = "metadata_description"
        case forsale
        case metadata
        case image
        case rarity = "metadata_rarity"
    }

    let identifier: String
    let collectionId: String
    let name: String?
    let description: String?
    let forsale: Decimal?
    let metadata: String?
    let image: String?
    let rarity: String?
}

struct RMRKNftMetadataV2: Codable {
    enum CodingKeys: String, CodingKey {
        case mediaUri
        case thumbnailUri
        case externalUri
        case description
        case name
        case externalUrl = "external_url"
        case image
        case imageData = "image_data"
        case animationUrl = "animation_url"
    }

    let mediaUri: String?
    let thumbnailUri: String?
    let externalUri: String?
    let description: String?
    let name: String?
    let externalUrl: String?
    let image: String?
    let imageData: String?
    let animationUrl: String?
}
