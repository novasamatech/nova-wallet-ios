import Foundation

enum Staking {
    static let module = "Staking"

    static var historyDepthStoragePath: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "HistoryDepth")
    }

    static var historyDepthCostantPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "HistoryDepth")
    }
}
