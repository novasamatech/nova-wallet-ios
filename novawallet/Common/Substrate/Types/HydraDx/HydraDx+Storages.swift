import Foundation

extension HydraDx {
    static var omnipoolAssets: StorageCodingPath {
        StorageCodingPath(moduleName: Self.omniPoolModule, itemName: "Assets")
    }

    static var dynamicFees: StorageCodingPath {
        StorageCodingPath(moduleName: "DynamicFees", itemName: "AssetFee")
    }
}
