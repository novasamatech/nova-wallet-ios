import RobinHood

extension Array where Element: Identifiable {
    func diff(
        from newItems: [Element],
        by compareClosure: (Element, Element) -> Bool
    ) -> SyncChanges<Element> {
        let oldItems = self
        let newMapping = newItems.reduce(into: [String: Element]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let oldMapping = oldItems.reduce(into: [String: Element]()) { mapping, item in
            mapping[item.identifier] = item
        }

        let newOrUpdated: [Element] = newItems.compactMap { newItem in
            if let oldItem = oldMapping[newItem.identifier] {
                return !compareClosure(oldItem, newItem) ? newItem : nil
            } else {
                return newItem
            }
        }

        let removed = oldItems.compactMap { oldItem in
            newMapping[oldItem.identifier] == nil ? oldItem : nil
        }

        return SyncChanges(newOrUpdatedItems: newOrUpdated, removedItems: removed)
    }
}
