import Foundation
import RobinHood
import CoreData

final class ProxiedSettingsMapper {
    var entityIdentifierFieldName: String { #keyPath(CDProxiedSettings.identifier) }

    typealias DataProviderModel = ProxiedSettings
    typealias CoreDataEntity = CDProxiedSettings
}

extension ProxiedSettingsMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        ProxiedSettings(identifier: entity.identifier!, confirmsOperation: entity.confirmsOperation)
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.confirmsOperation = model.confirmsOperation
    }
}
