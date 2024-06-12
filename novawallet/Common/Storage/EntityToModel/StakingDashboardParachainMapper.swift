import Foundation
import BigInt
import Operation_iOS
import CoreData

extension Multistaking.DashboardItemParachainPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardParachainMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemParachainPart
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardParachainMapper: CoreDataMapperProtocol {
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

        entity.stake = model.state.stake.map { String($0) }
        entity.onchainState = Multistaking.DashboardItemOnchainState.from(parachainState: model.state)?.rawValue
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
