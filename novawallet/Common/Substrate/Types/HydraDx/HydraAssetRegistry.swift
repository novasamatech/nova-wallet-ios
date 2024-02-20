import Foundation
import SubstrateSdk

enum HydraAssetRegistry {
    static let module = "AssetRegistry"

    struct AssetMetadata: Decodable {
        @StringCodable var decimals: UInt8
    }
}
