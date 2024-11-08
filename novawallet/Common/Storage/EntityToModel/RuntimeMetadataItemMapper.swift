import Foundation
import CoreData
import Operation_iOS

final class RuntimeMetadataItemMapper {
    var entityIdentifierFieldName: String { #keyPath(CDRuntimeMetadataItem.identifier) }

    typealias DataProviderModel = RuntimeMetadataItem
    typealias CoreDataEntity = CDRuntimeMetadataItem
}

extension RuntimeMetadataItemMapper: CoreDataMapperProtocol {
    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.chain
        entity.version = Int32(bitPattern: model.version)
        entity.txVersion = Int32(bitPattern: model.txVersion)
        entity.localMigratorVersion = Int32(bitPattern: model.localMigratorVersion)
        entity.opaque = model.opaque
        entity.metadata = model.metadata
    }

    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        RuntimeMetadataItem(
            chain: entity.identifier!,
            version: UInt32(bitPattern: entity.version),
            txVersion: UInt32(bitPattern: entity.txVersion),
            localMigratorVersion: UInt32(bitPattern: entity.localMigratorVersion),
            opaque: entity.opaque,
            metadata: entity.metadata!
        )
    }
}
