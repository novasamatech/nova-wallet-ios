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

    private func move(
        state: Multistaking.DashboardItem.State?,
        ledgerState: UncertainStorage<StakingLedger?>
    ) -> Multistaking.DashboardItem.State? {
        guard case let .defined(optLedger) = ledgerState else {
            return state
        }

        guard optLedger != nil else {
            return nil
        }

        if state == nil {
            return .inactive
        } else {
            return state
        }
    }

    private func move(
        state: Multistaking.DashboardItem.State?,
        activeEraState: UncertainStorage<ActiveEraInfo>,
        nominationState: UncertainStorage<Nomination?>
    ) -> Multistaking.DashboardItem.State? {
        guard
            case let state = state,
            case let .defined(activeEra) = activeEraState,
            case let .defined(optNomination) = nominationState,
            let nomination = optNomination else {
            return state
        }

        if state == .inactive, activeEra.index <= nomination.submittedIn {
            return .waiting
        } else {
            return state
        }
    }
}

extension StakingDashboardRelaychainMapper: CoreDataMapperProtocol {
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

        if case let .defined(activeStake) = model.stateChange.ledger.map({ $0?.active }) {
            entity.stake = activeStake.map { String($0) }
        }

        var currentState = entity.state.flatMap { Multistaking.DashboardItem.State(rawValue: $0) }

        currentState = move(
            state: currentState,
            ledgerState: model.stateChange.ledger
        )

        currentState = move(
            state: currentState,
            activeEraState: model.stateChange.era,
            nominationState: model.stateChange.nomination
        )

        entity.state = currentState?.rawValue
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        // we only can write partial state but not read
        fatalError("Unsupported method")
    }
}
