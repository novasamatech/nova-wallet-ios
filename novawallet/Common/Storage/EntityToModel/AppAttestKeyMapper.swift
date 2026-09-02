import Foundation
import Operation_iOS
import CoreData

final class AppAttestKeyMapper {
    var entityIdentifierFieldName: String {
        #keyPath(CDAppAttestKey.identifier)
    }

    typealias DataProviderModel = AppAttestKeySettings
    typealias CoreDataEntity = CDAppAttestKey
}

extension AppAttestKeyMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DataProviderModel(
            identifier: entity.identifier!,
            keyId: entity.keyId!,
            isAttested: entity.isAttested
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.keyId = model.keyId
        entity.isAttested = model.isAttested
    }
}
