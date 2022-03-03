import Foundation
import RobinHood

struct RemoteNftModel: Equatable, Identifiable {
    let identifier: NftModel.Id
    let chainId: String
    let ownerId: AccountId
    let collectionId: String?
    let instanceId: String?
    let metadata: Data?
    let totalIssuance: Int32?
    let name: String?
    let label: String?
    let media: String?
    let price: String?
    let type: UInt16

    init(
        identifier: String,
        type: UInt16,
        chainId: String,
        ownerId: AccountId,
        collectionId: String? = nil,
        instanceId: String? = nil,
        metadata: Data? = nil,
        totalIssuance: Int32? = nil,
        name: String? = nil,
        label: String? = nil,
        media: String? = nil,
        price: String? = nil
    ) {
        self.identifier = identifier
        self.type = type
        self.chainId = chainId
        self.ownerId = ownerId
        self.collectionId = collectionId
        self.instanceId = instanceId
        self.metadata = metadata
        self.totalIssuance = totalIssuance
        self.name = name
        self.label = label
        self.media = media
        self.price = price
    }

    init(localModel: NftModel) {
        identifier = localModel.identifier
        type = localModel.type
        chainId = localModel.chainId
        ownerId = localModel.ownerId
        collectionId = localModel.collectionId
        instanceId = localModel.instanceId
        metadata = localModel.metadata
        totalIssuance = localModel.totalIssuance
        name = localModel.name
        label = localModel.label
        media = localModel.media
        price = localModel.price
    }
}
