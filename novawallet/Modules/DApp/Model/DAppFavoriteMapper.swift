import Foundation
import CoreData
import Operation_iOS

final class DAppFavoriteMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = DAppFavorite
    typealias CoreDataEntity = CDDAppFavorite

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DAppFavorite(
            identifier: entity.identifier!,
            label: entity.label,
            icon: entity.icon,
            index: Int(entity.index)
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.icon = model.icon
        entity.label = model.label

        if let index = model.index {
            entity.index = Int64(index)
        }
    }

    var entityIdentifierFieldName: String { #keyPath(CDDAppFavorite.identifier) }
}
