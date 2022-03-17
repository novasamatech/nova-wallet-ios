import Foundation
import RobinHood

struct NftModel: Identifiable, Equatable {
    // swiftlint:disable:next type_name
    typealias Id = String

    let identifier: Id
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
    let createdAt: Date?

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
        price: String? = nil,
        createdAt: Date? = nil
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
        self.createdAt = createdAt
    }

    init(remoteModel: RemoteNftModel) {
        identifier = remoteModel.identifier
        type = remoteModel.type
        chainId = remoteModel.chainId
        ownerId = remoteModel.ownerId
        collectionId = remoteModel.collectionId
        instanceId = remoteModel.instanceId
        metadata = remoteModel.metadata
        totalIssuance = remoteModel.totalIssuance
        name = remoteModel.name
        label = remoteModel.label
        media = remoteModel.media
        price = remoteModel.price
        createdAt = nil
    }
}
