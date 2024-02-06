import Foundation
import BigInt
import SubstrateSdk

enum HydraDx {
    typealias OmniPoolAssetId = BigUInt
    static let nativeAssetId = OmniPoolAssetId(0)
    static let omniPoolModule = "Omnipool"
    static let dynamicFeesModule = "DynamicFees"
    static let multiTxPaymentModule = "MultiTransactionPayment"
    static let referralsModule = "Referrals"

    struct AssetsKey: JSONListConvertible {
        let assetId: OmniPoolAssetId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            guard jsonList.count == 1 else {
                throw CommonError.dataCorruption
            }

            assetId = try jsonList[0].map(
                to: StringScaleMapper<OmniPoolAssetId>.self,
                with: context
            ).value
        }
    }

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

    struct FeeParameters: Decodable {
        @StringCodable var minFee: BigUInt
    }

    struct FeeEntry: Decodable {
        @StringCodable var assetFee: BigUInt
        @StringCodable var protocolFee: BigUInt
    }

    static func getPoolAccountId(for size: Int) throws -> AccountId {
        guard let accountIdPrefix = "modlomnipool".data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let zeroAccountId = AccountId.zeroAccountId(of: size)

        return (accountIdPrefix + zeroAccountId).prefix(size)
    }
}
