import Foundation
import Operation_iOS
import CoreData
import BigInt

extension Multistaking.DashboardItemSubtensorPart: Identifiable {
    var identifier: String { stakingOption.stringValue }
}

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

        let state = Multistaking.DashboardItemOnchainState.from(subtensorState: model.state)

        switch state {
        case .bonded, .active, .waiting, .activeIndependent:
            entity.stake = String(model.state.totalStakeInRao)
            entity.subtensorRootStake = model.state.rootStakeInRao.map { String($0) }
            entity.subtensorSubnetCount = NSNumber(value: model.state.subnetCount)
            entity.subtensorIsFullyPriced = model.isFullyPriced.map { NSNumber(value: $0) }
        case nil:
            entity.stake = nil
            entity.subtensorRootStake = nil
            entity.subtensorSubnetCount = nil
            entity.subtensorIsFullyPriced = nil
        }

        entity.onchainState = state?.rawValue
        entity.subtensorRootRate = model.rootRate.map { $0 as NSDecimalNumber }

        if case let .replace(maxApy) = model.maxApy {
            entity.maxApy = maxApy.map { $0 as NSDecimalNumber }
        }
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
