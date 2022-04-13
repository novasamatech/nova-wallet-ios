import Foundation
import CoreData
import RobinHood

final class DAppFavoriteMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = DAppFavorite
    typealias CoreDataEntity = CDDAppFavorite

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DAppFavorite(identifier: entity.identifier!, label: entity.label, icon: entity.icon)
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.icon = model.icon
        entity.label = model.label
    }

    var entityIdentifierFieldName: String { #keyPath(CDDAppSettings.identifier) }
}
