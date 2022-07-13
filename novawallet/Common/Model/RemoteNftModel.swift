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

extension RemoteNftModel {
    static func createFromRMRKV2(
        _ remoteItem: RMRKNftV2,
        ownerId: AccountId,
        chainId: ChainModel.Id,
        collection: RMRKV2Collection?
    ) -> RemoteNftModel {
        let identifier = NftModel.rmrkv2Identifier(
            for: chainId,
            identifier: remoteItem.identifier
        )

        let metadata: Data?

        if let metadataString = remoteItem.metadata {
            metadata = metadataString.data(using: .utf8)
        } else {
            metadata = nil
        }

        let price = remoteItem.forsale.map(\.stringWithPointSeparator)

        let imageUrl: String?

        if
            let imageString = remoteItem.image,
            !DistributedUrlParser().isDistributedUrl(imageString) {
            imageUrl = imageString
        } else {
            imageUrl = nil
        }

        return RemoteNftModel(
            identifier: identifier,
            type: NftType.rmrkV2.rawValue,
            chainId: chainId,
            ownerId: ownerId,
            collectionId: remoteItem.collectionId,
            instanceId: nil,
            metadata: metadata,
            totalIssuance: collection?.max,
            name: remoteItem.symbol,
            label: remoteItem.serialNumber,
            media: imageUrl,
            price: price
        )
    }
}
