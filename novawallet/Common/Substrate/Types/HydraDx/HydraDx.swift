import Foundation
import BigInt
import SubstrateSdk

enum HydraDx {
    typealias OmniPoolAssetId = BigUInt
    static let omniPoolModule = "Omnipool"

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
        @StringCodable var hubReserve: BigUInt
        @StringCodable var shares: BigUInt
        @StringCodable var protocolShares: BigUInt
        @StringCodable var tradable: UInt8
    }

    static func getPoolAccountId(for size: Int) throws -> AccountId {
        guard let accountIdPrefix = "modlomnipool".data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let zeroAccountId = AccountId.zeroAccountId(of: size)

        return (accountIdPrefix + zeroAccountId).prefix(size)
    }
}
