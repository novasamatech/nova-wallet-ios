import Foundation
import Operation_iOS
import CoreData
import BigInt

final class AssetLockMapper {
    var entityIdentifierFieldName: String { #keyPath(CDAssetLock.identifier) }

    typealias DataProviderModel = AssetLock
    typealias CoreDataEntity = CDAssetLock
}

extension AssetLockMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainAccountId = model.accountId.toHex()
        entity.chainId = model.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.chainAssetId.assetId)
        entity.storage = model.storage
        entity.amount = String(model.amount)
        entity.type = model.type.toUTF8String()!
        entity.module = model.module
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.chainAccountId!)
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0
        let chainAssetId = ChainAssetId(
            chainId: entity.chainId!,
            assetId: UInt32(bitPattern: entity.assetId)
        )
        return .init(
            chainAssetId: chainAssetId,
            accountId: accountId,
            type: entity.type!.data(using: .utf8)!,
            amount: amount,
            storage: entity.storage!,
            module: entity.module
        )
    }
}
