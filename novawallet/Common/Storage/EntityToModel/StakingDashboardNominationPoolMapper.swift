import Foundation
import BigInt
import RobinHood
import CoreData

extension Multistaking.DashboardItemNominationPoolPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardNominationPoolMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemNominationPoolPart
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardNominationPoolMapper: CoreDataMapperProtocol {
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

        if let state = model.state {
            entity.stake = state.poolMemberStake.map { String($0) }

            entity.onchainState = Multistaking.DashboardItemOnchainState.from(nominationPoolState: state)?.rawValue
        } else {
            entity.stake = nil
            entity.onchainState = nil
        }
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
