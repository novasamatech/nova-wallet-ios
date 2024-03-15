import Foundation
import SubstrateSdk

enum HydraAssetRegistry {
    static let module = "AssetRegistry"

    struct Asset: Decodable {
        @StringCodable var decimals: UInt8
    }
}
