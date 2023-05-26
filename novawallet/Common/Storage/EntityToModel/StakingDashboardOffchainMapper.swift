import Foundation
import BigInt
import RobinHood
import CoreData

extension Multistaking.DashboardItemOffchainPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardOffchainMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemOffchainPart
    typealias CoreDataEntity = CDStakingDashboardItem

    private func move(
        state: Multistaking.DashboardItem.State?,
        hasAssignedStake: Bool
    ) -> Multistaking.DashboardItem.State? {
        hasAssignedStake ? .active : state
    }
}

extension StakingDashboardOffchainMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.walletId = model.stakingOption.walletId

        let chainAssetId = model.stakingOption.option.chainAssetId
        entity.chainId = chainAssetId.chainId
        entity.assetId = Int32(bitPattern: chainAssetId.assetId)

        entity.stakingType = model.stakingOption.option.type.rawValue

        var currentState = entity.state.flatMap { Multistaking.DashboardItem.State(rawValue: $0) }

        currentState = move(state: currentState, hasAssignedStake: model.hasAssignedStake)
        entity.state = currentState?.rawValue

        entity.maxApy = model.maxApy as NSDecimalNumber
        entity.totalRewards = model.totalRewards.map { String($0) }
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
