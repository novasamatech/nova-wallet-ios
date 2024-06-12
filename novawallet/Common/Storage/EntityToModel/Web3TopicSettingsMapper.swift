import Foundation
import Operation_iOS
import CoreData

final class Web3TopicSettingsMapper {
    var entityIdentifierFieldName: String { #keyPath(CDUserSingleValue.identifier) }

    typealias DataProviderModel = PushNotification.TopicSettings
    typealias CoreDataEntity = CDUserSingleValue
}

extension Web3TopicSettingsMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let decoder = JSONDecoder()
        return try decoder.decode(DataProviderModel.self, from: entity.payload!)
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        let encoder = JSONEncoder()
        entity.identifier = model.identifier
        entity.payload = try encoder.encode(model)
    }
}
