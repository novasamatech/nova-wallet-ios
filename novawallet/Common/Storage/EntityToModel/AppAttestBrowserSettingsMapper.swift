import Foundation
import Operation_iOS
import CoreData

final class AppAttestBrowserSettingsMapper {
    var entityIdentifierFieldName: String {
        #keyPath(CDAppAttestBrowserSettings.baseURL)
    }

    typealias DataProviderModel = AppAttestBrowserSettings
    typealias CoreDataEntity = CDAppAttestBrowserSettings
}

extension AppAttestBrowserSettingsMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DataProviderModel(
            baseURL: entity.baseURL!,
            keyId: entity.keyId!,
            isAttested: entity.isAttested
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.baseURL = model.baseURL
        entity.keyId = model.keyId
        entity.isAttested = model.isAttested
    }
}
