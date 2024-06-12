import Foundation
import BigInt
import Operation_iOS
import CoreData

extension Multistaking.DashboardItemOffchainPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardOffchainMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemOffchainPart
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardOffchainMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.walletId = model.stakingOption.walletId

        let chainAssetId = model.stakingOption.option.chainAssetId
        entity.chainId = chainAssetId.chainId
        entity.assetId = Int32(bitPattern: chainAssetId.assetId)

        entity.stakingType = model.stakingOption.option.type.rawValue

        entity.hasAssignedStake = model.hasAssignedStake

        entity.maxApy = model.maxApy as NSDecimalNumber
        entity.totalRewards = model.totalRewards.map { String($0) }
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
