import Foundation
import SubstrateSdk

struct EquilibriumAssetExtras: Codable {
    @StringCodable var assetId: UInt64
    let transfersEnabled: Bool?
}
