import Foundation
import Operation_iOS
import CoreData

final class AssetVisibilityMapper {
    var entityIdentifierFieldName: String { #keyPath(CDAssetVisibility.identifier) }

    typealias DataProviderModel = AssetVisibilityLocal
    typealias CoreDataEntity = CDAssetVisibility
}

extension AssetVisibilityMapper: CoreDataMapperProtocol {
    func transform(entity: CoreDataEntity) throws -> DataProviderModel {
        guard
            entity.identifier != nil,
            let metaId = entity.metaId,
            let chainId = entity.chainId,
            let state = AssetVisibilityState(rawValue: entity.state)
        else {
            throw CommonError.dataCorruption
        }

        return AssetVisibilityLocal(
            metaId: metaId,
            chainId: chainId,
            assetId: UInt32(bitPattern: entity.assetId),
            state: state
        )
    }

    func populate(
        entity: CoreDataEntity,
        from model: DataProviderModel,
        using _: NSManagedObjectContext
    ) throws {
        entity.identifier = model.identifier
        entity.metaId = model.metaId
        entity.chainId = model.chainId
        entity.assetId = Int32(bitPattern: model.assetId)
        entity.state = model.state.rawValue
    }
}
