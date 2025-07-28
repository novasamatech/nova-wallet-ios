import Foundation
import Operation_iOS
import CoreData

final class DelegatedAccountSettingsMapper {
    var entityIdentifierFieldName: String { #keyPath(CDProxiedSettings.identifier) }

    typealias DataProviderModel = DelegatedAccountSettings
    typealias CoreDataEntity = CDProxiedSettings
}

extension DelegatedAccountSettingsMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DelegatedAccountSettings(identifier: entity.identifier!, confirmsOperation: entity.confirmsOperation)
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
