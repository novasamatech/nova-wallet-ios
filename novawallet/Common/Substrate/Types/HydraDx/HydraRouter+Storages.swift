import Foundation
import SubstrateSdk

extension HydraRouter {
    static var routesPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.moduleName, itemName: "Routes")
    }
}

extension HydraRouter {
    struct AssetPair: Encodable {
        @StringCodable var assetIn: HydraDx.AssetId
        @StringCodable var assetOut: HydraDx.AssetId

        var isOrdered: Bool {
            assetIn <= assetOut
        }

        var ordered: AssetPair {
            isOrdered ? self : AssetPair(assetIn: assetOut, assetOut: assetIn)
        }
    }
}
