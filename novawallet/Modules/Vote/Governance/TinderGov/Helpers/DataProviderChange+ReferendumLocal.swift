import Operation_iOS
import SoraFoundation

extension DataProviderChange where T == ReferendumLocal {
    func itemIdentifier() -> ReferendumIdLocal {
        switch self {
        case let .insert(newItem):
            return newItem.index
        case let .update(newItem):
            return newItem.index
        case let .delete(deletedIdentifier):
            return UInt(deletedIdentifier)!
        }
    }
}

extension Array where Element == DataProviderChange<ReferendumLocal> {
    func mergeToDict(
        _ dict: [ReferendumIdLocal: ReferendumLocal]
    ) -> [ReferendumIdLocal: ReferendumLocal] {
        reduce(into: dict) { result, change in
            switch change {
            case let .insert(newItem), let .update(newItem):
                result[newItem.index] = newItem
            case let .delete(deletedIdentifier):
                result[change.itemIdentifier()] = nil
            }
        }
    }
}
