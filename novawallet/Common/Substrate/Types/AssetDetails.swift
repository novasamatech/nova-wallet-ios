import Foundation
import BigInt
import SubstrateSdk

struct AssetDetailsV1: Decodable {
    @StringCodable var minBalance: BigUInt
    let isFrozen: Bool
    let isSufficient: Bool
}

struct AssetDetailsV2: Decodable {
    enum Status: String, Decodable {
        case live = "Live"
        case frozen = "Frozen"
        case destroying = "Destroying"

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            guard let value = Status(rawValue: type) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected asset status"
                )
            }

            self = value
        }
    }

    @StringCodable var minBalance: BigUInt
    let status: Status
    let isSufficient: Bool
}

struct AssetDetails: Decodable {
    let minBalance: BigUInt
    let status: AssetDetailsV2.Status
    let isSufficient: Bool

    var isFrozen: Bool {
        status != .live
    }

    init(from decoder: Decoder) throws {
        if let detailsV2 = try? AssetDetailsV2(from: decoder) {
            minBalance = detailsV2.minBalance
            status = detailsV2.status
            isSufficient = detailsV2.isSufficient
        } else {
            let detailsV1 = try AssetDetailsV1(from: decoder)

            minBalance = detailsV1.minBalance
            status = detailsV1.isFrozen ? .frozen : .live
            isSufficient = detailsV1.isSufficient
        }
    }
}
