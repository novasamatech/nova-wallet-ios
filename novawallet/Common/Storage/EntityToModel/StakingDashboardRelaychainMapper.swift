import Foundation
import BigInt
import RobinHood
import CoreData

extension Multistaking.DashboardItemRelaychainPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardRelaychainMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemRelaychainPart
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardRelaychainMapper: CoreDataMapperProtocol {
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

        entity.stake = model.state.ledger.map { String($0.active) }
        entity.onchainState = Multistaking.DashboardItemOnchainState.from(relaychainState: model.state)?.rawValue
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
