import Foundation

extension HydraOmnipool {
    static var hubAssetIdPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.moduleName, constantName: "HubAssetId")
    }

    static var maxInRatioPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.moduleName, constantName: "MaxInRatio")
    }

    static var maxOutRatioPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.moduleName, constantName: "MaxOutRatio")
    }

    /// Named `MinimumTradingLimit` here and `MinTradingLimit` in XYK, even though both bind the same
    /// runtime value. Copying either name into the other pallet throws `invalidStoragePath`.
    static var minTradingLimitPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.moduleName, constantName: "MinimumTradingLimit")
    }

    static var assetsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.moduleName, itemName: "Assets")
    }

    static var slipFeePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.moduleName, itemName: "SlipFee")
    }
}
