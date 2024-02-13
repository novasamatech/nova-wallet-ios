import Foundation
import BigInt
import SubstrateSdk

enum HydraDx {
    typealias AssetId = BigUInt
    static let nativeAssetId = AssetId(0)
    static let dynamicFeesModule = "DynamicFees"
    static let multiTxPaymentModule = "MultiTransactionPayment"
    static let referralsModule = "Referrals"

    struct AssetsKey: JSONListConvertible {
        let assetId: HydraDx.AssetId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            guard jsonList.count == 1 else {
                throw CommonError.dataCorruption
            }

            assetId = try jsonList[0].map(
                to: StringScaleMapper<HydraDx.AssetId>.self,
                with: context
            ).value
        }
    }

    struct FeeParameters: Decodable {
        @StringCodable var minFee: BigUInt
    }

    struct FeeEntry: Decodable {
        @StringCodable var assetFee: BigUInt
        @StringCodable var protocolFee: BigUInt
    }
}
