import Foundation

struct RMRKNft: Codable {
    let collection: String
    let name: String
    let instance: String
    let owner: String
    let metadata: String?
}

struct RMRKNftMetadata: Codable {
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
