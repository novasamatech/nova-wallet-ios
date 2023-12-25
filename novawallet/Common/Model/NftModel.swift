import Foundation
import RobinHood
import BigInt

struct NftModel: Identifiable, Equatable {
    // swiftlint:disable:next type_name
    typealias Id = String

    let identifier: Id
    let chainId: String
    let ownerId: AccountId
    let collectionId: String?
    let instanceId: String?
    let metadata: Data?
    let issuanceTotal: BigUInt?
    let issuanceMyAmount: BigUInt?
    let name: String?
    let label: String?
    let media: String?
    let price: String?
    let priceUnits: String?
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
        issuanceTotal: BigUInt? = nil,
        issuanceMyAmount: BigUInt? = nil,
        name: String? = nil,
        label: String? = nil,
        media: String? = nil,
        price: String? = nil,
        priceUnits: String? = nil,
        createdAt: Date? = nil
    ) {
        self.identifier = identifier
        self.type = type
        self.chainId = chainId
        self.ownerId = ownerId
        self.collectionId = collectionId
        self.instanceId = instanceId
        self.metadata = metadata
        self.issuanceTotal = issuanceTotal
        self.issuanceMyAmount = issuanceMyAmount
        self.name = name
        self.label = label
        self.media = media
        self.price = price
        self.priceUnits = priceUnits
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
        issuanceTotal = remoteModel.issuanceTotal
        issuanceMyAmount = remoteModel.issuanceMyAmount
        name = remoteModel.name
        label = remoteModel.label
        media = remoteModel.media
        price = remoteModel.price
        priceUnits = remoteModel.priceUnits
        createdAt = nil
    }
}
