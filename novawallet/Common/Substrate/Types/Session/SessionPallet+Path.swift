import Foundation

extension SessionPallet {
    static var validatorsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "Validators")
    }

    static var currentSessionIndexPath: StorageCodingPath {
        StorageCodingPath(moduleName: "Session", itemName: "CurrentIndex")
    }
}
