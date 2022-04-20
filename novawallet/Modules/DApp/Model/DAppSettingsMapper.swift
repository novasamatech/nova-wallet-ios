import Foundation
import RobinHood
import CoreData

final class DAppSettingsMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = DAppSettings
    typealias CoreDataEntity = CDDAppSettings

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DAppSettings(identifier: entity.identifier!, metaId: entity.metaId)
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.metaId = model.metaId
    }

    var entityIdentifierFieldName: String { #keyPath(CDDAppSettings.identifier) }
}
