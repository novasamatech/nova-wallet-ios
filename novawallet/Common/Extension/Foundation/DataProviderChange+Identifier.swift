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

extension Array where Element: Identifiable {
    func applying(changes: [DataProviderChange<Element>]) -> Self {
        changes.reduce(into: self) { result, change in
            switch change {
            case let .insert(item), let .update(item):
                result.addOrReplaceSingle(item)
            case let .delete(deletedIdentifier):
                result = result.filter { $0.identifier != deletedIdentifier }
            }
        }
    }
}
