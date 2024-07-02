import Foundation
import SubstrateSdk

extension HydraDx {
    static func deriveAccount(
        from asset1: HydraDx.AssetId,
        asset2: HydraDx.AssetId,
        identifier: String
    ) throws -> AccountId {
        guard let initData = identifier.data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let assets: Data = if asset1 < asset2 {
            Data(UInt32(asset1).littleEndianBytes + UInt32(asset2).littleEndianBytes)
        } else {
            Data(UInt32(asset2).littleEndianBytes + UInt32(asset1).littleEndianBytes)
        }

        return try (initData + assets).blake2b32()
    }
}
