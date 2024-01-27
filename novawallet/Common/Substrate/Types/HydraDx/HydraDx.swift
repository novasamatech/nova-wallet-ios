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
}
