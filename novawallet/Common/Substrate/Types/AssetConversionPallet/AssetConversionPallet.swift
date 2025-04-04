import Foundation
import SubstrateSdk
import BigInt

enum AssetConversionPallet {
    static let name = "AssetConversion"

    struct AssetId: Codable {
        let location: XcmUni.RelativeLocation

        init(from decoder: any Decoder) throws {
            location = try XcmUni.RelativeLocation(from: decoder, configuration: .V4)
        }

        func encode(to encoder: any Encoder) throws {
            try location.encode(to: encoder, configuration: .V4)
        }

        init(parents: UInt8, interior: XcmUni.Junctions) {
            location = XcmUni.RelativeLocation(parents: parents, interior: interior)
        }
    }

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
    var items: [XcmUni.Junction] { get }
}

extension AssetConversionPallet.AssetId: AssetConversionAssetIdProtocol {
    var parents: UInt8 { location.parents }
    var items: [XcmUni.Junction] { location.interior.items }
}

extension XcmUni.RelativeLocation: AssetConversionAssetIdProtocol {
    var items: [XcmUni.Junction] { interior.items }
}
