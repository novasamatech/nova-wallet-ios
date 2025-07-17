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
    let owner: String
    let name: String?
    let description: String?
    let image: String?
}
