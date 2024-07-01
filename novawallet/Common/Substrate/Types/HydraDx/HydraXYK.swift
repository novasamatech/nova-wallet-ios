import Foundation
import SubstrateSdk

enum HydraXYK {
    static let name = "XYK"

    struct PoolAssets: Equatable, Decodable {
        let asset1: HydraDx.AssetId
        let asset2: HydraDx.AssetId

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            asset1 = try container.decode(StringScaleMapper<HydraDx.AssetId>.self).value
            asset2 = try container.decode(StringScaleMapper<HydraDx.AssetId>.self).value
        }
    }
}
