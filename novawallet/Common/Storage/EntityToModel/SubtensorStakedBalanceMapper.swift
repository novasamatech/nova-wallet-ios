import Foundation
import Operation_iOS
import CoreData
import BigInt

final class SubtensorStakedBalanceMapper {
    var entityIdentifierFieldName: String { #keyPath(CDExternalBalance.identifier) }

    typealias DataProviderModel = SubtensorStakedBalance
    typealias CoreDataEntity = CDExternalBalance
}

extension SubtensorStakedBalanceMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.chainAssetId.assetId)
        entity.type = ExternalAssetBalance.BalanceType.subtensorStaking.rawValue
        entity.subtype = nil
        entity.param = nil
        entity.chainAccountId = model.accountId.toHex()
        entity.amount = String(model.amount)
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.chainAccountId!)
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0

        return .init(
            chainAssetId: .init(chainId: entity.chainId!, assetId: .init(bitPattern: entity.assetId)),
            accountId: accountId,
            amount: amount
        )
    }
}
