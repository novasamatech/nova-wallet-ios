import Foundation
import SubstrateSdk
import BigInt

extension Referenda {
    struct LinearDecreasingCurve: Decodable {
        @StringCodable var length: BigUInt
        @StringCodable var floor: BigUInt
        @StringCodable var ceil: BigUInt
    }

    struct SteppedDecreasingCurve: Decodable {
        @StringCodable var begin: BigUInt
        @StringCodable var end: BigUInt
        @StringCodable var step: BigUInt
        @StringCodable var period: BigUInt
    }

    struct ReciprocalCurve: Decodable {
        @StringCodable var factor: Int64
        @StringCodable var xOffset: Int64
        @StringCodable var yOffset: Int64
    }

    enum Curve: Decodable {
        case linearDecreasing(_ params: LinearDecreasingCurve)
        case steppedDecreasing(_ params: SteppedDecreasingCurve)
        case reciprocal(_ params: ReciprocalCurve)
        case unknown

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)

            switch type {
            case "LinearDecreasing":
                let curve = try container.decode(LinearDecreasingCurve.self)
                self = .linearDecreasing(curve)
            case "SteppedDecreasing":
                let curve = try container.decode(SteppedDecreasingCurve.self)
                self = .steppedDecreasing(curve)
            case "Reciprocal":
                let curve = try container.decode(ReciprocalCurve.self)
                self = .reciprocal(curve)
            default:
                self = .unknown
            }
        }
    }
}
