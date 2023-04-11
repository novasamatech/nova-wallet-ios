import Foundation

extension StorageCodingPath {
    static var equilibriumBalances: StorageCodingPath {
        StorageCodingPath(moduleName: "System", itemName: "Account")
    }

    static var equilibriumLocks: StorageCodingPath {
        StorageCodingPath(moduleName: "EqBalances", itemName: "Locked")
    }

    static var equilibriumReserved: StorageCodingPath {
        StorageCodingPath(moduleName: "EqBalances", itemName: "Reserved")
    }
}
