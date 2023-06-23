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

        if case let .defined(activeStake) = model.stateChange.ledger.map({ $0?.active }) {
            entity.stake = activeStake.map { String($0) }
        }

        if case let .defined(optNomination) = model.stateChange.nomination {
            entity.startedAt = optNomination.map { NSNumber(value: Int64(bitPattern: UInt64($0.submittedIn))) }
            
            if optNomination == nil {
                entity.expectedOnchain = false
            }
        }
        
        if case let .defined(activeEra) = model.stateChange.era {
            if let startedAt = entity.startedAt.map({ UInt32(bitPattern: Int32(truncating: $0)) }) {
                entity.expectedOnchain = startedAt < activeEra.index
            } else {
                entity.expectedOnchain = false
            }
        }
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
