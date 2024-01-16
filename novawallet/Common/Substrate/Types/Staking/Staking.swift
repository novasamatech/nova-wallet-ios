import Foundation
import BigInt
import SubstrateSdk

enum Staking {
    static let module = "Staking"

    static var historyDepthStoragePath: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "HistoryDepth")
    }

    static var eraStakersOverview: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasStakersOverview")
    }

    static var eraStakersPaged: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasStakersPaged")
    }

    static var claimedRewards: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ClaimedRewards")
    }

    static var historyDepthCostantPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "HistoryDepth")
    }

    static var maxUnlockingChunksConstantPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "MaxUnlockingChunks")
    }
}
