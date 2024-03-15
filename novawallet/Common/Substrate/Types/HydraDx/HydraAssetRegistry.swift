import Foundation
import SubstrateSdk

enum HydraAssetRegistry {
    static let module = "AssetRegistry"

    struct Asset: Decodable {
        @OptionStringCodable var decimals: UInt8?
    }
}
