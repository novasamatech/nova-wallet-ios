import Foundation
import SubstrateSdk
import BigInt

enum HydraOmnipool {
    static let moduleName = "Omnipool"

    struct AssetState: Decodable {
        struct Tradable: Decodable {
            @StringCodable var bits: UInt8

            func matches(flags: UInt8) -> Bool {
                (bits & flags) == flags
            }

            func canSell() -> Bool {
                matches(flags: 1 << 0)
            }

            func canBuy() -> Bool {
                matches(flags: 1 << 1)
            }
        }

        @StringCodable var hubReserve: BigUInt
        @StringCodable var shares: BigUInt
        @StringCodable var protocolShares: BigUInt
        let tradable: Tradable
    }

    static func getPoolAccountId(for size: Int) throws -> AccountId {
        guard let accountIdPrefix = "modlomnipool".data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let zeroAccountId = AccountId.zeroAccountId(of: size)

        return (accountIdPrefix + zeroAccountId).prefix(size)
    }
}
