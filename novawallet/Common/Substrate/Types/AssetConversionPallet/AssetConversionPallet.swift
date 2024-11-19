import Foundation
import SubstrateSdk
import BigInt

enum AssetConversionPallet {
    static let name = "AssetConversion"

    typealias AssetId = XcmV4.Multilocation

    enum PoolAsset {
        case native
        case assets(pallet: UInt8, index: BigUInt)
        case foreign(AssetId)
        case undefined(AssetId)
    }

    struct PoolAssetPair {
        let asset1: PoolAsset
        let asset2: PoolAsset
    }

    struct AssetIdPair: JSONListConvertible {
        let asset1: AssetId
        let asset2: AssetId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 1
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            guard let poolId = jsonList[0].arrayValue, poolId.count == 2 else {
                throw JSONListConvertibleError.unexpectedValue(jsonList[0])
            }

            asset1 = try poolId[0].map(to: AssetId.self, with: context)
            asset2 = try poolId[1].map(to: AssetId.self, with: context)
        }
    }
}

protocol AssetConversionAssetIdProtocol {
    var parents: UInt8 { get }
    var items: [XcmV3.Junction] { get }
}

extension AssetConversionPallet.AssetId: AssetConversionAssetIdProtocol {
    var items: [XcmV3.Junction] { interior.items }
}

extension XcmV3.Multilocation: AssetConversionAssetIdProtocol {
    var items: [XcmV3.Junction] { interior.items }
}
