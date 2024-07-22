import Foundation
import Operation_iOS
import CoreData
import BigInt

final class AssetHoldMapper {
    var entityIdentifierFieldName: String { #keyPath(CDAssetLock.identifier) }

    typealias DataProviderModel = AssetHold
    typealias CoreDataEntity = CDAssetHold
}

extension AssetHoldMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainAccountId = model.accountId.toHex()
        entity.chainId = model.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.chainAssetId.assetId)
        entity.module = model.module
        entity.reason = model.reason
        entity.amount = String(model.amount)
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.chainAccountId!)
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0
        let chainAssetId = ChainAssetId(
            chainId: entity.chainId!,
            assetId: UInt32(bitPattern: entity.assetId)
        )
        return AssetHold(
            chainAssetId: chainAssetId,
            accountId: accountId,
            module: entity.module!,
            reason: entity.reason!,
            amount: amount
        )
    }
}
