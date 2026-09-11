import Foundation
import CoreData
import Operation_iOS
@testable import NovaAnalytics

enum CorruptAnalyticsEventMapperError: Error {
    case dataCorruption
}

final class CorruptAnalyticsEventMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = AnalyticsPendingEvent
    typealias CoreDataEntity = CDAnalyticsEvent

    var entityIdentifierFieldName: String {
        #keyPath(CDAnalyticsEvent.identifier)
    }

    func transform(entity _: CoreDataEntity) throws -> DataProviderModel {
        throw CorruptAnalyticsEventMapperError.dataCorruption
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.sequence = model.sequence
    }
}
