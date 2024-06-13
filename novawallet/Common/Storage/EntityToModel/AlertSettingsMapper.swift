import Foundation
import Operation_iOS
import CoreData

final class Web3AlertSettingsMapper {
    var entityIdentifierFieldName: String { #keyPath(CDUserSingleValue.identifier) }

    typealias DataProviderModel = Web3Alert.LocalSettings
    typealias CoreDataEntity = CDUserSingleValue
}

extension Web3AlertSettingsMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DataProviderModel.self, from: entity.payload!)
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        entity.identifier = model.identifier
        entity.payload = try encoder.encode(model)
    }
}
