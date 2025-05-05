import Foundation

extension SystemPallet {
    static var accountPath: StorageCodingPath {
        .init(moduleName: name, itemName: "Account")
    }

    static var blockNumberPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "Number")
    }

    static var eventsPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "Events")
    }

    static var blockWeightPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "BlockWeight")
    }
}
