import Foundation
import RobinHood
import CoreData
import BigInt

final class CrowdloanContributionDataMapper {
    var entityIdentifierFieldName: String { #keyPath(CDCrowdloanContribution.identifier) }

    typealias DataProviderModel = CrowdloanContributionData
    typealias CoreDataEntity = CDCrowdloanContribution
}

extension CrowdloanContributionDataMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.chainId = model.chainId
        entity.paraId = Int32(model.paraId)
        entity.source = model.source
        entity.chainAccountId = model.accountId.toHex()
        entity.amount = String(model.amount)
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let accountId = try Data(hexString: entity.chainAccountId!)
        let amount = entity.amount.map { BigUInt($0) ?? 0 } ?? 0
        let paraId = UInt32(entity.paraId)

        return .init(
            accountId: accountId,
            chainId: entity.chainId!,
            paraId: paraId,
            source: entity.source,
            amount: amount
        )
    }
}
