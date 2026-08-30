import Foundation

extension HydraXYK {
    static var poolAssetsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "PoolAssets")
    }

    static var exchangeFeePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "GetExchangeFee")
    }

    static var maxInRatioPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "MaxInRatio")
    }

    static var maxOutRatioPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "MaxOutRatio")
    }

    /// Named `MinTradingLimit` here and `MinimumTradingLimit` in Omnipool, even though both bind the
    /// same runtime value. Copying either name into the other pallet throws `invalidStoragePath`.
    static var minTradingLimitPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "MinTradingLimit")
    }
}
