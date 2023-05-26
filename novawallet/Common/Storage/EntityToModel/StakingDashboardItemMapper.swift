import Foundation
import CoreData
import RobinHood
import BigInt

extension Multistaking.DashboardItem: Identifiable {
    var identifier: String {
        stakingOption.stringValue
    }
}

final class StakingDashboardItemMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStakingDashboardItem.identifier) }

    typealias DataProviderModel = Multistaking.DashboardItem
    typealias CoreDataEntity = CDStakingDashboardItem
}

extension StakingDashboardItemMapper: CoreDataMapperProtocol {
    func populate(
        entity _: CoreDataEntity,
        from _: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        // we only can read state but not write
        fatalError("Only can be changed by onchain and offchain mappers")
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let chainAssetId = ChainAssetId(
            chainId: entity.chainId!,
            assetId: AssetModel.Id(bitPattern: entity.assetId)
        )

        let stakingType = StakingType(rawType: entity.stakingType)
        let stakingOption = Multistaking.OptionWithWallet(
            walletId: entity.walletId!,
            option: .init(chainAssetId: chainAssetId, type: stakingType)
        )

        let state = entity.state.flatMap { Multistaking.DashboardItem.State(rawValue: $0) }
        let stake = entity.stake.flatMap { BigUInt($0) }
        let totalRewards = entity.totalRewards.flatMap { BigUInt($0) }
        let maxApy = entity.maxApy as Decimal?

        return .init(
            stakingOption: stakingOption,
            state: state,
            stake: stake,
            totalRewards: totalRewards,
            maxApy: maxApy
        )
    }
}
