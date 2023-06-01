import Foundation
import BigInt
import RobinHood
import CoreData

extension Multistaking.DashboardItemParachainPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

final class StakingDashboardParachainMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItemParachainPart
    typealias CoreDataEntity = CDStakingDashboardItem

    private func move(
        state: Multistaking.DashboardItem.State?,
        onchainState: Multistaking.ParachainStateChange
    ) -> Multistaking.DashboardItem.State? {
        guard onchainState.stake != nil else {
            return nil
        }

        switch state {
        case .active:
            return state
        case .inactive, .waiting, .none:
            return onchainState.shouldHaveActiveCollator ? .waiting : .inactive
        }
    }
}

extension StakingDashboardParachainMapper: CoreDataMapperProtocol {
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

        entity.stake = model.stateChange.stake.map { String($0) }

        var currentState = entity.state.flatMap { Multistaking.DashboardItem.State(rawValue: $0) }

        currentState = move(
            state: currentState,
            onchainState: model.stateChange
        )

        entity.state = currentState?.rawValue
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
