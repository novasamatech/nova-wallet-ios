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
            categories: entity.categories?.split(by: .comma),
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

        if let categories = model.categories {
            entity.categories = categories.joined(with: .comma)
        }

        if let index = model.index {
            entity.index = Int64(index)
        }
    }

    var entityIdentifierFieldName: String { #keyPath(CDDAppSettings.identifier) }
}
