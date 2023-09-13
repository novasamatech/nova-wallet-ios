import Foundation
import RobinHood
import CoreData
import BigInt

final class CrowdloanContributionDataMapper {
    var entityIdentifierFieldName: String { #keyPath(CDExternalBalance.identifier) }

    typealias DataProviderModel = CrowdloanContributionData
    typealias CoreDataEntity = CDExternalBalance
}

extension CrowdloanContributionDataMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.chainAssetId.chainId
        entity.assetId = Int32(bitPattern: model.chainAssetId.assetId)
        entity.type = ExternalAssetBalance.BalanceType.crowdloan.rawValue
        entity.subtype = model.source
        entity.param = String(model.paraId)
        entity.chainAccountId = model.accountId.toHex()
        entity.amount = String(model.amount)
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.chainAccountId!)
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0
        let paraId = entity.param.flatMap { UInt32($0) }

        return .init(
            accountId: accountId,
            chainAssetId: ChainAssetId(chainId: entity.chainId!, assetId: .init(bitPattern: entity.assetId)),
            paraId: paraId ?? 0,
            source: entity.subtype,
            amount: amount
        )
    }
}
