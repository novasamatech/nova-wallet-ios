import Foundation

extension Treasury {
    static var proposalsStoragePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "Proposals")
    }
}
