import Foundation
import SubstrateSdk

enum HydraAssetRegistry {
    static let module = "AssetRegistry"

    struct Asset: Decodable {
        @OptionStringCodable var decimals: UInt8?
        let assetType: AssetType
    }

    enum AssetType: Decodable, Equatable {
        case erc20
        case other(String)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Erc20":
                self = .erc20
            default:
                self = .other(type)
            }
        }
    }
}
