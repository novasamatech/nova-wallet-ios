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

    static var minTradingLimitPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "MinTradingLimit")
    }
}
