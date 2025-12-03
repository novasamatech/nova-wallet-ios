import Foundation
import Operation_iOS
import CoreData
import BigInt

final class CrowdloanContributionDataMapper {
    var entityIdentifierFieldName: String { #keyPath(CDExternalBalance.identifier) }

    typealias DataProviderModel = CrowdloanContribution
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
        entity.subtype = nil
        entity.param = String(model.paraId)
        entity.param2 = String(model.unlocksAt)
        entity.param3 = model.depositor?.toHex()
        entity.chainAccountId = model.accountId.toHex()
        entity.amount = String(model.amount)
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.chainAccountId!)
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0
        let paraId = entity.param.flatMap { ParaId($0) }
        let unlocksAt = entity.param2.flatMap { BlockNumber($0) }
        let depositor = try entity.param3.flatMap { try Data(hexString: $0) }

        return .init(
            accountId: accountId,
            chainAssetId: ChainAssetId(chainId: entity.chainId!, assetId: .init(bitPattern: entity.assetId)),
            paraId: paraId ?? 0,
            unlocksAt: unlocksAt ?? 0,
            amount: amount,
            depositor: depositor
        )
    }
}
