import Foundation
import CoreData
import Operation_iOS

final class DAppGlobalSettingsMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = DAppGlobalSettings
    typealias CoreDataEntity = CDDAppGlobalSettings

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DAppGlobalSettings(
            identifier: entity.identifier!,
            desktopMode: entity.desktopDisplayMode
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.desktopDisplayMode = model.desktopMode
    }

    var entityIdentifierFieldName: String { #keyPath(CDDAppGlobalSettings.identifier) }
}
