import Foundation
import RobinHood
import CoreData

final class ParaStkScheduledRequestsMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = ParachainStaking.MappedScheduledRequest
    typealias CoreDataEntity = CDChainStorageItem

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        let item: [ParachainStaking.DelegatorScheduledRequest]?

        if let data = entity.data {
            item = try JSONDecoder().decode([ParachainStaking.DelegatorScheduledRequest].self, from: data)
        } else {
            item = nil
        }

        return DataProviderModel(identifier: entity.identifier!, item: item)
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        let data: Data?

        if let item = model.item {
            data = try JSONEncoder().encode(item)
        } else {
            data = nil
        }

        entity.identifier = model.identifier
        entity.data = data
    }

    var entityIdentifierFieldName: String { #keyPath(CoreDataEntity.identifier) }
}
