import Foundation
import Operation_iOS

extension DataProviderChange {
    var item: T? {
        switch self {
        case let .insert(newItem), let .update(newItem):
            return newItem
        case .delete:
            return nil
        }
    }

    var isDeletion: Bool {
        switch self {
        case .insert, .update:
            return false
        case .delete:
            return true
        }
    }

    static func change<P: Identifiable & Equatable>(
        value1: P?,
        value2: P?
    ) -> DataProviderChange<P>? {
        guard let currentItem = value1 else {
            if let newItem = value2 {
                return DataProviderChange<P>.insert(newItem: newItem)
            } else {
                return nil
            }
        }

        guard let newItem = value2 else {
            return DataProviderChange<P>.delete(deletedIdentifier: currentItem.identifier)
        }

        if newItem != currentItem {
            return DataProviderChange<P>.update(newItem: newItem)
        } else {
            return nil
        }
    }
}
