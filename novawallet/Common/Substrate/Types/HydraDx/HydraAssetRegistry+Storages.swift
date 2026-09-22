import Foundation
import SubstrateSdk

extension HydraAssetRegistry {
    static var assetsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.module, itemName: "Assets")
    }

    static var assetLocationsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.module, itemName: "AssetLocations")
    }

    struct AssetLocationKey: JSONListConvertible, Hashable {
        let assetId: HydraDx.AssetId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            guard jsonList.count == 1 else {
                throw CommonError.dataCorruption
            }

            assetId = try jsonList[0].map(
                to: StringScaleMapper<HydraDx.AssetId>.self,
                with: context
            ).value
        }
    }
}
