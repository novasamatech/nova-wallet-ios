import Foundation
import BigInt
import SubstrateSdk

extension PalletAssets {
    struct DetailsV1: Decodable {
        @StringCodable var minBalance: BigUInt
        let isFrozen: Bool
        let isSufficient: Bool
    }

    struct DetailsV2: Decodable {
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
        @BytesCodable var issuer: AccountId
    }

    struct Details: Decodable {
        let minBalance: BigUInt
        let status: DetailsV2.Status
        let isSufficient: Bool

        var isFrozen: Bool {
            status != .live
        }

        init(from decoder: Decoder) throws {
            if let detailsV2 = try? DetailsV2(from: decoder) {
                minBalance = detailsV2.minBalance
                status = detailsV2.status
                isSufficient = detailsV2.isSufficient
            } else {
                let detailsV1 = try DetailsV1(from: decoder)

                minBalance = detailsV1.minBalance
                status = detailsV1.isFrozen ? .frozen : .live
                isSufficient = detailsV1.isSufficient
            }
        }
    }
}
