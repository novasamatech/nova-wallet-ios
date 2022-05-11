import Foundation

struct StorageListSyncResult<U, T> {
    struct Item {
        let key: U
        let value: T
    }

    let items: [Item]
}
