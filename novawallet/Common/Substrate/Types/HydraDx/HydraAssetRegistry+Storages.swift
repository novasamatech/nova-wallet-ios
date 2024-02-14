import Foundation

extension HydraAssetRegistry {
    static var assetMetadata: StorageCodingPath {
        StorageCodingPath(moduleName: Self.module, itemName: "AssetMetadataMap")
    }
}
