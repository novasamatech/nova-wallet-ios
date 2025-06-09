import Foundation
import BigInt
import SubstrateSdk

struct UniqueScanNftResponse: Codable {
    let items: [UniqueScanNftRemoteModel]
    let count: Int
}

struct UniqueScanNftRemoteModel: Codable {
    let key: String
    let collectionId: Int
    let tokenId: Int
    let collectionAddress: String
    let tokenAddress: String
    let owner: String
    let topmostOwner: String
    let isBundle: Bool
    let properties: [UniqueNftProperty]
    let propertiesMap: [String: UniqueNftProperty]
    let schemaName: String?
    let schemaVersion: String?
    let name: String?
    let description: String?
    let image: String?
    let attributes: [UniqueNftAttribute]?
    let media: UniqueNftMedia?
    let isBurned: Bool
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case key, collectionId, tokenId, collectionAddress, tokenAddress
        case owner, topmostOwner, isBundle, properties, propertiesMap
        case schemaName, schemaVersion, name, description, image
        case attributes, media, isBurned, updatedAt
    }
}

// Supporting types
struct UniqueNftProperty: Codable {
    let key: String
    let keyHex: String
    let value: String
    let valueHex: String
}

struct UniqueNftAttribute: Codable {
    let traitType: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case traitType = "trait_type"
        case value
    }
}

struct UniqueNftMedia: Codable {
    let whitepaper: UniqueNftMediaItem?
    let sound: UniqueNftMediaItem?
}

struct UniqueNftMediaItem: Codable {
    let type: String?
    let url: String?
}
