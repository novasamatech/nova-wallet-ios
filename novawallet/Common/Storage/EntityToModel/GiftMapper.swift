import Foundation
import Operation_iOS
import CoreData
import BigInt

final class GiftMapper {
    var entityIdentifierFieldName: String { #keyPath(CDGift.identifier) }

    typealias DataProviderModel = GiftModel
    typealias CoreDataEntity = CDGift
}

extension GiftMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DataProviderModel(
            amount: entity.amount.flatMap { BigUInt($0) }!,
            chainAssetId: ChainAssetId(chainId: entity.chainId!, assetId: UInt32(bitPattern: entity.assetId)),
            status: GiftModel.Status(rawValue: entity.status)!,
            giftAccountId: try Data(hexString: entity.giftAccountId!),
            metaId: entity.metaId!
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.amount = String(model.amount)
        entity.chainId = model.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.chainAssetId.assetId)
        entity.status = model.status.rawValue
        entity.giftAccountId = model.giftAccountId.toHex()
        entity.metaId = model.metaId
        entity.identifier = model.identifier
    }
}
