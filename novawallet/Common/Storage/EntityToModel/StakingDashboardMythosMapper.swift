import Foundation
import Operation_iOS
import CoreData
import BigInt

extension Multistaking.DashboardItemMythosStakingPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardMythosMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemMythosStakingPart
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardMythosMapper: CoreDataMapperProtocol {
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

        let state = Multistaking.DashboardItemOnchainState.from(mythosState: model.state)

        switch state {
        case .bonded, .active, .waiting, .activeIndependent:
            entity.stake = String(model.state.userStake?.stake ?? 0)
        case nil:
            entity.stake = nil
        }

        entity.onchainState = state?.rawValue
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
