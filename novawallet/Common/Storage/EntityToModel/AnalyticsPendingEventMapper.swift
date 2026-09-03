import Foundation
import Operation_iOS
import CoreData

final class AnalyticsPendingEventMapper {
    var entityIdentifierFieldName: String {
        #keyPath(CDAnalyticsEvent.identifier)
    }

    typealias DataProviderModel = AnalyticsPendingEvent
    typealias CoreDataEntity = CDAnalyticsEvent
}

extension AnalyticsPendingEventMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        guard
            let identifier = entity.identifier,
            let name = entity.name,
            let timestamp = entity.timestamp,
            let payload = entity.payload
        else {
            throw CommonError.dataCorruption
        }

        return DataProviderModel(
            identifier: identifier,
            sequence: entity.sequence,
            name: name,
            timestamp: timestamp,
            payload: payload
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.sequence = model.sequence
        entity.name = model.name
        entity.timestamp = model.timestamp
        entity.payload = model.payload
    }
}
