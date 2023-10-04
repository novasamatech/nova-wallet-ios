import Foundation
import SubstrateSdk
import BigInt

enum AssetConversionPallet {
    static let name = "AssetConversion"

    typealias AssetId = XcmV3.Multilocation

    enum PoolAsset {
        case native
        case assets(pallet: UInt8, index: BigUInt)
        case foreign(AssetId)
        case undefined(AssetId)

        init(multilocation: XcmV3.Multilocation) {
            let junctions = multilocation.interior.items

            if multilocation.parents == 0 {
                guard !junctions.isEmpty else {
                    self = .native
                    return
                }

                switch junctions[0] {
                case let .palletInstance(pallet):
                    if
                        junctions.count == 2,
                        case let .generalIndex(index) = junctions[1] {
                        self = .assets(pallet: pallet, index: index)
                    } else {
                        self = .undefined(multilocation)
                    }
                default:
                    self = .undefined(multilocation)
                }
            } else {
                self = .foreign(multilocation)
            }
        }
    }

    struct PoolAssetPair: JSONListConvertible {
        let asset1: PoolAsset
        let asset2: PoolAsset

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

            let multilocation1 = try poolId[0].map(to: AssetId.self, with: context)
            let multilocation2 = try poolId[1].map(to: AssetId.self, with: context)

            asset1 = PoolAsset(multilocation: multilocation1)
            asset2 = PoolAsset(multilocation: multilocation2)
        }
    }
}
