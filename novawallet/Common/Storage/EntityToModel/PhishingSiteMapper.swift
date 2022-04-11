import Foundation
import RobinHood
import CoreData

final class PhishingSiteMapper {
    var entityIdentifierFieldName: String { #keyPath(CDPhishingSite.identifier) }

    typealias DataProviderModel = PhishingSite
    typealias CoreDataEntity = CDPhishingSite
}

extension PhishingSiteMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.host
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        PhishingSite(host: entity.identifier!)
    }
}
