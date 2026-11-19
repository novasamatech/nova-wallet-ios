import Foundation

extension HydraStableswap {
    static var pools: StorageCodingPath {
        StorageCodingPath(moduleName: Self.module, itemName: "Pools")
    }

    static var tradability: StorageCodingPath {
        StorageCodingPath(moduleName: Self.module, itemName: "AssetTradability")
    }

    static var poolPegs: StorageCodingPath {
        StorageCodingPath(moduleName: Self.module, itemName: "PoolPegs")
    }

    static var minTradingLimitPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.module, constantName: "MinTradingLimit")
    }
}
