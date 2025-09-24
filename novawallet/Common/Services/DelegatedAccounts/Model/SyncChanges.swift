struct SyncChanges<Item> {
    var newOrUpdatedItems: [Item] = []
    var removedItems: [Item] = []

    var isEmpty: Bool {
        newOrUpdatedItems.isEmpty && removedItems.isEmpty
    }
}
