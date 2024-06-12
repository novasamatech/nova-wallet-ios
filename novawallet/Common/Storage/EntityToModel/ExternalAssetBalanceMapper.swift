import Foundation
import Operation_iOS
import CoreData
import BigInt

final class ExternalAssetBalanceMapper {
    var entityIdentifierFieldName: String { #keyPath(CDExternalBalance.identifier) }

    typealias DataProviderModel = ExternalAssetBalance
    typealias CoreDataEntity = CDExternalBalance
}

extension ExternalAssetBalanceMapper: CoreDataMapperProtocol {
    func populate(
        entity _: CoreDataEntity,
        from _: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        fatalError("Use source specific mapper to save data")
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.chainAccountId!)
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0

        return .init(
            identifier: entity.identifier!,
            chainAssetId: .init(chainId: entity.chainId!, assetId: .init(bitPattern: entity.assetId)),
            accountId: accountId,
            amount: amount,
            type: .init(rawType: entity.type!),
            subtype: entity.subtype,
            param: entity.param
        )
    }
}
