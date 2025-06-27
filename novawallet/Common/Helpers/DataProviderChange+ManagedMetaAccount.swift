import Foundation
import Operation_iOS

extension DataProviderChange where T == ManagedMetaAccountModel {
    var infoChange: DataProviderChange<MetaAccountModel> {
        switch self {
        case let .insert(newItem): .insert(newItem: newItem.info)
        case let .update(newItem): .update(newItem: newItem.info)
        case let .delete(deletedIdentifier): .delete(deletedIdentifier: deletedIdentifier)
        }
    }
}

extension Array where Element == DataProviderChange<ManagedMetaAccountModel> {
    func mapToInfoChanges() -> [DataProviderChange<MetaAccountModel>] {
        map { $0.infoChange }
    }
}
