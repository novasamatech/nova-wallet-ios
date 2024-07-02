import Foundation

extension HydraXYK {
    static var poolAssetsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "PoolAssets")
    }

    static var exchangeFeePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "GetExchangeFee")
    }
}
