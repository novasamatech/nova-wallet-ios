import Foundation
import RobinHood
import CoreData
import BigInt

final class AssetBalanceMapper {
    var entityIdentifierFieldName: String { #keyPath(CDAssetBalance.identifier) }

    typealias DataProviderModel = AssetBalance
    typealias CoreDataEntity = CDAssetBalance
}

extension AssetBalanceMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainAccountId = model.accountId.toHex()
        entity.chainId = model.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.chainAssetId.assetId)
        entity.freeInPlank = String(model.freeInPlank)
        entity.reservedInPlank = String(model.reservedInPlank)
        entity.frozenInPlank = String(model.frozenInPlank)
    }

    func transform(entity: CDAssetBalance) throws -> AssetBalance {
        let free = entity.freeInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let reserved = entity.reservedInPlank.map { BigUInt($0) ?? 0 } ?? 0
        let frozen = entity.frozenInPlank.map { BigUInt($0) ?? 0 } ?? 0

        let accountId = try Data(hexString: entity.chainAccountId!)

        return AssetBalance(
            chainAssetId: ChainAssetId(
                chainId: entity.chainId!,
                assetId: UInt32(bitPattern: entity.assetId)
            ),
            accountId: accountId,
            freeInPlank: free,
            reservedInPlank: reserved,
            frozenInPlank: frozen
        )
    }
}
