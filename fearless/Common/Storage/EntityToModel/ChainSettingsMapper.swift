import Foundation
import RobinHood
import CoreData

final class ChainSettingsMapper {
    var entityIdentifierFieldName: String { #keyPath(CDChainSettings.chainId) }

    typealias DataProviderModel = ChainSettingsModel
    typealias CoreDataEntity = CDChainSettings
}

extension ChainSettingsMapper: CoreDataMapperProtocol {
    func transform(entity: CDChainSettings) throws -> ChainSettingsModel {
        ChainSettingsModel(autobalanced: entity.autobalanced, chainId: entity.chainId!)
    }

    func populate(entity: CDChainSettings, from model: ChainSettingsModel, using _: NSManagedObjectContext) throws {
        entity.autobalanced = model.autobalanced
        entity.chainId = model.chainId
    }
}
