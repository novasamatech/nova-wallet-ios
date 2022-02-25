import Foundation
import RobinHood

struct DataChangesDiffCalculator<T: Identifiable & Equatable> {
    struct Changes {
        let newOrUpdatedItems: [T]
        let removedItems: [T]
    }

    func diff(newItems: [T], oldItems: [T]) -> Changes {
        let newMapping = newItems.reduce(into: [String: T]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let oldMapping = oldItems.reduce(into: [String: T]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let newOrUpdated: [T] = newItems.compactMap { newItem in
            if let oldItem = oldMapping[newItem.identifier] {
                return oldItem != newItem ? newItem : nil
            } else {
                return newItem
            }
        }

        let removed = oldItems.compactMap { oldItem in
            newMapping[oldItem.identifier] == nil ? oldItem : nil
        }

        return Changes(newOrUpdatedItems: newOrUpdated, removedItems: removed)
    }
}
