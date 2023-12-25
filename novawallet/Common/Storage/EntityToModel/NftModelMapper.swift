import Foundation
import RobinHood
import CoreData
import BigInt

final class NftModelMapper {
    var entityIdentifierFieldName: String { #keyPath(CDNft.identifier) }

    typealias DataProviderModel = NftModel
    typealias CoreDataEntity = CDNft
}

extension NftModelMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.chainId
        entity.ownerId = model.ownerId.toHex()
        entity.collectionId = model.collectionId
        entity.instanceId = model.instanceId
        entity.metadata = model.metadata
        entity.issuanceTotal = model.issuanceTotal.map { String($0) }
        entity.issuanceMyAmount = model.issuanceMyAmount.map { String($0) }
        entity.name = model.name
        entity.label = model.label
        entity.price = model.price
        entity.priceUnits = model.priceUnits
        entity.media = model.media
        entity.type = Int16(bitPattern: model.type)

        if entity.createdAt == nil {
            entity.createdAt = Date()
        }
    }

    func transform(entity: CDNft) throws -> DataProviderModel {
        let ownerId = try Data(hexString: entity.ownerId!)

        return NftModel(
            identifier: entity.identifier!,
            type: UInt16(bitPattern: entity.type),
            chainId: entity.chainId!,
            ownerId: ownerId,
            collectionId: entity.collectionId,
            instanceId: entity.instanceId,
            metadata: entity.metadata,
            issuanceTotal: entity.issuanceTotal.flatMap { BigUInt($0) },
            issuanceMyAmount: entity.issuanceMyAmount.flatMap { BigUInt($0) },
            name: entity.name,
            label: entity.label,
            media: entity.media,
            price: entity.price,
            priceUnits: entity.priceUnits,
            createdAt: entity.createdAt
        )
    }
}
