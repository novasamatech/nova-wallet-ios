import Foundation
import Operation_iOS
import CoreData
import BigInt

final class DAppBrowserTabMapper {
    var entityIdentifierFieldName: String { #keyPath(CDDAppBrowserTab.identifier) }

    typealias DataProviderModel = DAppBrowserTab.PersistenceModel
    typealias CoreDataEntity = CDDAppBrowserTab
}

extension DAppBrowserTabMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DAppBrowserTab.PersistenceModel(
            uuid: UUID(uuidString: entity.identifier!)!,
            name: entity.label,
            url: entity.url,
            lastModified: entity.lastModified!,
            icon: entity.icon,
            desktopOnly: entity.desktopOnly
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.label = model.name
        entity.url = model.url
        entity.lastModified = model.lastModified
        entity.icon = model.icon
        entity.desktopOnly = model.desktopOnly ?? false
    }
}
