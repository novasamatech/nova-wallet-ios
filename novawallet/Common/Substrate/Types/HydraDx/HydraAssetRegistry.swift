import Foundation
import SubstrateSdk

enum HydraAssetRegistry {
    static let module = "AssetRegistry"

    struct AssetMetadata {
        @StringCodable var decimals: UInt8
    }
}
