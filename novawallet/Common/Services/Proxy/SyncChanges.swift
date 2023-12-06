struct SyncChanges<Item> {
    let newOrUpdatedItems: [Item]
    let removedItems: [Item]
}

typealias ChainAccountChanges = SyncChanges<ChainAccountModel>
