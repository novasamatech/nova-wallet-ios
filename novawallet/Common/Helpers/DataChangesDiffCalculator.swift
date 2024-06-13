import Foundation
import Operation_iOS

struct DataChangesDiffCalculator<T: Identifiable> {
    struct Changes {
        let newOrUpdatedItems: [T]
        let removedItems: [T]
    }

    func diff(
        newItems: [T],
        oldItems: [T],
        by compareClosure: (T, T) -> Bool
    ) -> Changes {
        let newMapping = newItems.reduce(into: [String: T]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let oldMapping = oldItems.reduce(into: [String: T]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let newOrUpdated: [T] = newItems.compactMap { newItem in
            if let oldItem = oldMapping[newItem.identifier] {
                return !compareClosure(oldItem, newItem) ? newItem : nil
            } else {
                return newItem
            }
        }

        let removed = oldItems.compactMap { oldItem in
            newMapping[oldItem.identifier] == nil ? oldItem : nil
        }

        return Changes(newOrUpdatedItems: newOrUpdated, removedItems: removed)
    }

    func diff(newItems: [T], oldItems: [T]) -> Changes where T: Equatable {
        diff(newItems: newItems, oldItems: oldItems, by: ==)
    }

    func calculateChanges(newItems: [T], oldItems: [T]) -> [DataProviderChange<T>] where T: Equatable {
        let newMapping = newItems.reduce(into: [String: T]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let oldMapping = oldItems.reduce(into: [String: T]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let newOrUpdated: [DataProviderChange<T>] = newItems.compactMap { newItem in
            if let oldItem = oldMapping[newItem.identifier] {
                return oldItem != newItem ? DataProviderChange.update(newItem: newItem) : nil
            } else {
                return DataProviderChange.insert(newItem: newItem)
            }
        }

        let removed: [DataProviderChange<T>] = oldItems.compactMap { oldItem in
            newMapping[oldItem.identifier] == nil ?
                DataProviderChange.delete(deletedIdentifier: oldItem.identifier) :
                nil
        }

        return newOrUpdated + removed
    }
}
