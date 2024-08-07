import Foundation
import BigInt

extension HydraXYK {
    static func deriveAccount(
        from asset1: HydraDx.AssetId,
        asset2: HydraDx.AssetId
    ) throws -> AccountId {
        try HydraDx.deriveAccount(from: asset1, asset2: asset2, identifier: "xyk")
    }
}
