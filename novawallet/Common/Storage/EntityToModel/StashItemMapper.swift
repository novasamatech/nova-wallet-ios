import Foundation
import Operation_iOS
import CoreData

final class StashItemMapper {
    var entityIdentifierFieldName: String { #keyPath(CDStashItem.identifier) }

    typealias DataProviderModel = StashItem
    typealias CoreDataEntity = CDStashItem
}

extension StashItemMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = StashItem.createIdentifier(from: model.stash, chainId: model.chainId)
        entity.stash = model.stash
        entity.controller = model.controller
        entity.chainId = model.chainId
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        .init(stash: entity.stash!, controller: entity.controller!, chainId: entity.chainId ?? "")
    }
}
