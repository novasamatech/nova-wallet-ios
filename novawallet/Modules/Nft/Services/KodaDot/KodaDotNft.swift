import Foundation
import BigInt
import SubstrateSdk

struct KodaDotNftResponse: Codable {
    let nftEntities: [KodaDotNftRemoteModel]
}

struct KodaDotNftRemoteModel: Codable {
    struct Collection: Codable {
        enum CodingKeys: String, CodingKey {
            case identifier = "id"
            case max
        }

        let identifier: String
        let max: UInt?
    }

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case image
        case metadata
        case name
        case price
        case serialNumber = "sn"
        case currentOwner
        case collection
    }

    let identifier: String
    let image: String?
    let metadata: String?
    let name: String?
    let price: String?
    let serialNumber: String?
    let currentOwner: AccountAddress
    let collection: Collection?
}

struct KodaDotNftMetadataResponse: Codable {
    let metadataEntityById: KodaDotNftMetadataRemoteModel?
}

struct KodaDotNftMetadataRemoteModel: Codable {
    let name: String?
    let description: String?
    let type: String?
    let image: String?
}

struct KodaDotNftCollectionResponse: Codable {
    let collectionEntityById: KodaDotNftCollectionRemoteModel?
}

struct KodaDotNftCollectionRemoteModel: Codable {
    let name: String?
    let image: String?
    let issuer: String?
}
