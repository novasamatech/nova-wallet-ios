import Foundation
import SubstrateSdk
import BigInt

extension HydraStableswap {
    struct PoolPegInfo: Decodable {
        let current: [[StringCodable<Balance>]]
    }

    static func getDefaultPegs(for poolAssetsCount: Int) -> [[StringCodable<BigUInt>]] {
        (0 ..< poolAssetsCount).map { _ in
            [StringCodable<BigUInt>(wrappedValue: 1), StringCodable<BigUInt>(wrappedValue: 1)]
        }
    }
}
