import Foundation
import SubstrateSdk

struct RMRKNftV2: Codable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case collectionId
        case symbol
        case serialNumber = "sn"
        case forsale
        case metadata
        case image
    }

    let identifier: String
    let collectionId: String
    let symbol: String?
    let serialNumber: String?
    let forsale: Decimal?
    let metadata: String?
    let image: String?
}

struct RMRKNftMetadataV2: Codable {
    enum CodingKeys: String, CodingKey {
        case description
        case properties
        case mediaUri
        case name
    }

    let description: String?
    let properties: JSON?
    let mediaUri: String?
    let name: String?
}
