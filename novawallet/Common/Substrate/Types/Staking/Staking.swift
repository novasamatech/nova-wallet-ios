import Foundation

enum Staking {
    static var historyDepthStoragePath: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "HistoryDepth")
    }

    static var historyDepthCostantPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: "Staking", constantName: "HistoryDepth")
    }
}
