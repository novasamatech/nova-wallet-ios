import Foundation
import Operation_iOS
import CoreData

final class DAppSettingsMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = DAppSettings
    typealias CoreDataEntity = CDDAppSettings

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DAppSettings(
            dAppId: entity.dAppId ?? entity.identifier!,
            metaId: entity.metaId!,
            source: entity.source
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.dAppId = model.dAppId
        entity.metaId = model.metaId
        entity.source = model.source
    }

    var entityIdentifierFieldName: String { #keyPath(CDDAppSettings.identifier) }
}
