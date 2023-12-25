import Foundation
import RobinHood
import BigInt

struct RemoteNftModel: Equatable, Identifiable {
    let identifier: NftModel.Id
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
        priceUnits: String? = nil
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
    }

    init(localModel: NftModel) {
        identifier = localModel.identifier
        type = localModel.type
        chainId = localModel.chainId
        ownerId = localModel.ownerId
        collectionId = localModel.collectionId
        instanceId = localModel.instanceId
        metadata = localModel.metadata
        issuanceTotal = localModel.issuanceTotal
        issuanceMyAmount = localModel.issuanceMyAmount
        name = localModel.name
        label = localModel.label
        media = localModel.media
        price = localModel.price
        priceUnits = localModel.priceUnits
    }
}

extension RemoteNftModel {
    static func createFromRMRKV1(
        _ remoteItem: RMRKNftV1,
        ownerId: AccountId,
        chainId: ChainModel.Id,
        collection: RMRKV1Collection?
    ) -> RemoteNftModel {
        let identifier = NftModel.rmrkv1Identifier(
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

        return RemoteNftModel(
            identifier: identifier,
            type: NftType.rmrkV1.rawValue,
            chainId: chainId,
            ownerId: ownerId,
            collectionId: remoteItem.collectionId,
            instanceId: remoteItem.instance,
            metadata: metadata,
            issuanceTotal: collection?.max.map { BigUInt($0) },
            issuanceMyAmount: nil,
            name: remoteItem.name,
            label: remoteItem.serialNumber,
            media: nil,
            price: price,
            priceUnits: nil
        )
    }

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

        if let imageString = remoteItem.image {
            if let parsingResult = DistributedUrlParser().parse(url: imageString) {
                imageUrl = DistributedStorageOperationFactory.resolveUrl(from: parsingResult).absoluteString
            } else {
                imageUrl = imageString
            }
        } else {
            imageUrl = nil
        }

        return RemoteNftModel(
            identifier: identifier,
            type: NftType.rmrkV2.rawValue,
            chainId: chainId,
            ownerId: ownerId,
            collectionId: remoteItem.collectionId,
            instanceId: remoteItem.identifier,
            metadata: metadata,
            issuanceTotal: collection?.max.map { BigUInt($0) },
            issuanceMyAmount: nil,
            name: remoteItem.symbol,
            label: remoteItem.serialNumber,
            media: imageUrl,
            price: price,
            priceUnits: nil
        )
    }
}
