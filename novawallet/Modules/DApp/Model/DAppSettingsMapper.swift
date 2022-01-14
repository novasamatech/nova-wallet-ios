import Foundation
import RobinHood
import CoreData

final class DAppSettingsMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = DAppSettings
    typealias CoreDataEntity = CDDAppSettings

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DAppSettings(
            identifier: entity.identifier!,
            allowed: entity.allowed,
            favorite: entity.favorite
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.allowed = model.allowed
        entity.favorite = model.favorite
    }

    var entityIdentifierFieldName: String { #keyPath(CDDAppSettings.identifier) }
}
