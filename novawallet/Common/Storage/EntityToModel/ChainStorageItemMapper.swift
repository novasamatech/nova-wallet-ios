import Foundation
import CoreData
import Operation_iOS

final class ChainStorageItemMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChainStorageItem.identifier) }

    typealias DataProviderModel = ChainStorageItem
    typealias CoreDataEntity = CDChainStorageItem
}

extension ChainStorageItemMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.data = model.data
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        DataProviderModel(identifier: entity.identifier!, data: entity.data!)
    }
}
