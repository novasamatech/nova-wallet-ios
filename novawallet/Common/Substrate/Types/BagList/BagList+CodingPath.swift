import Foundation

extension BagList {
    static func bagThresholdsPath(for moduleName: String) -> ConstantCodingPath {
        .init(moduleName: moduleName, constantName: "BagThresholds")
    }

    static func bagListSizePath(for moduleName: String) -> StorageCodingPath {
        .init(moduleName: moduleName, itemName: "CounterForListNodes")
    }

    static var defaultBagListSizePath: StorageCodingPath {
        bagListSizePath(for: BagList.defaultModuleName)
    }
}
