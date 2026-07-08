import Foundation
import Operation_iOS
import CoreData

extension Multistaking.DashboardItemSubtensorPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

/// Maps Subtensor on-chain stake state to CDStakingDashboardItem.
/// Mirrors StakingDashboardMythosMapper — writes only, never reads.
final class StakingDashboardSubtensorMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemSubtensorPart
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardSubtensorMapper: CoreDataMapperProtocol {
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

        // One row per (ChainAsset, .subtensor) → one netuid. The stake value is the
        // user's alpha amount for that netuid (TAO for netuid=0, subnet alpha otherwise).
        if model.state.totalStake > 0 {
            entity.stake = String(model.state.totalStake)
            // activeIndependent: no offchain check needed — stake is self-evident
            entity.onchainState = Multistaking.DashboardItemOnchainState.activeIndependent.rawValue
        } else {
            entity.stake = nil
            entity.onchainState = nil
        }
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        fatalError("StakingDashboardSubtensorMapper is write-only")
    }
}
