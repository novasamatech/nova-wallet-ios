import RobinHood

extension DataProviderChange where T: Identifiable {
    var identifier: String {
        switch self {
        case let .insert(newItem), let .update(newItem):
            return newItem.identifier
        case let .delete(deletedIdentifier):
            return deletedIdentifier
        }
    }
}
