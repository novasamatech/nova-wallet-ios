import Foundation
import Operation_iOS
import CoreData

final class TransactionHistoryResolutionMapper {
    struct Model: Identifiable {
        let identifier: String
        let outcome: TransactionTrackingOutcome
    }

    var entityIdentifierFieldName: String { #keyPath(CDTransactionItem.identifier) }

    typealias DataProviderModel = Model
    typealias CoreDataEntity = CDTransactionItem
}

extension TransactionHistoryResolutionMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using context: NSManagedObjectContext
    ) throws {
        // A row deleted after the fetch is never recreated half-filled.
        guard !entity.isInserted else {
            context.delete(entity)
            return
        }

        let resolution = Self.resolution(for: model.outcome)
        let storedStatus = TransactionHistoryItem.Status(rawValue: entity.status) ?? .pending

        guard !TransactionHistoryStatusRank.isDowngrade(from: storedStatus, to: resolution.status) else {
            return
        }

        entity.status = resolution.status.rawValue

        if let fee = resolution.fee {
            entity.fee = fee
        }

        if let blockNumber = resolution.blockNumber {
            entity.blockNumber = NSNumber(value: blockNumber)
        }
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        throw CommonError.dataCorruption
    }
}

private extension TransactionHistoryResolutionMapper {
    static func resolution(
        for outcome: TransactionTrackingOutcome
    ) -> (status: TransactionHistoryItem.Status, fee: String?, blockNumber: UInt64?) {
        switch outcome {
        case let .included(inclusion):
            (.success, inclusion.actualFee.map { String($0) }, inclusion.blockNumber)
        case let .includedFailed(inclusion, _):
            (.failed, inclusion.actualFee.map { String($0) }, inclusion.blockNumber)
        case .dropped:
            (.failed, "0", nil)
        }
    }
}
