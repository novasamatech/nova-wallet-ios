import Foundation
import RobinHood

struct NftModel: Identifiable, Equatable {
    let identifier: String
    let chainId: String
    let ownerId: AccountId
    let collectionId: String?
    let instanceId: String?
    let metadata: Data?
    let name: String?
    let label: String?
    let media: String?
    let price: String?
    let type: UInt16
    let creationAt: Date?

    init(
        identifier: String,
        type: UInt16,
        chainId: String,
        ownerId: AccountId,
        collectionId: String? = nil,
        instanceId: String? = nil,
        metadata: Data? = nil,
        name: String? = nil,
        label: String? = nil,
        media: String? = nil,
        price: String? = nil,
        creationAt: Date? = nil
    ) {
        self.identifier = identifier
        self.type = type
        self.chainId = chainId
        self.ownerId = ownerId
        self.collectionId = collectionId
        self.instanceId = instanceId
        self.metadata = metadata
        self.name = name
        self.label = label
        self.media = media
        self.price = price
        self.creationAt = creationAt
    }
}
