import Foundation
import Operation_iOS
import CoreData

final class MetaAccountSettingsMapper {
    var entityIdentifierFieldName: String { #keyPath(CDMetaAccountSettings.metaId) }

    typealias DataProviderModel = MetaAccountSettingsLocal
    typealias CoreDataEntity = CDMetaAccountSettings
}

extension MetaAccountSettingsMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        guard let metaId = entity.metaId else {
            throw CommonError.dataCorruption
        }

        return MetaAccountSettingsLocal(
            metaId: metaId,
            autoAddTokensWithBalance: entity.autoAddTokensWithBalance
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.metaId = model.metaId
        entity.autoAddTokensWithBalance = model.autoAddTokensWithBalance
    }
}
