import Foundation
import SubstrateSdk

enum AssetConversionPallet {
    static let name = "AssetConversion"

    struct PoolAssetPair {
        let asset1: JSON
        let asset2: JSON
    }

    extension PoolAssetPair: JSONListConvertible {
        init(jsonList: [JSON], context _: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            asset1 = try jsonList[0]
            asset2 = try jsonList[1]
        }
    }
}
