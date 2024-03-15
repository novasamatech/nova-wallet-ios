import Foundation

extension HydraAssetRegistry {
    static var assetsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.module, itemName: "Assets")
    }
}
