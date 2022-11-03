import Foundation
import SubstrateSdk
import BigInt

extension Referenda {
    /**
     * Linear curve starting at `(0, ceil)`, proceeding linearly to `(length, floor)`, then
     * remaining at `floor` until the end of the period.
     */
    struct LinearDecreasingCurve: Decodable {
        @StringCodable var length: BigUInt
        @StringCodable var floor: BigUInt
        @StringCodable var ceil: BigUInt
    }

    /**
     *  Stepped curve, beginning at `(0, begin)`, then remaining constant for `period`, at which
     *  point it steps down to `(period, begin - step)`. It then remains constant for another
     * `period` before stepping down to `(period * 2, begin - step * 2)`. This pattern continues
     *  but the `y` component has a lower limit of `end`.
     */
    struct SteppedDecreasingCurve: Decodable {
        @StringCodable var begin: BigUInt
        @StringCodable var end: BigUInt
        @StringCodable var step: BigUInt
        @StringCodable var period: BigUInt
    }

    /// A recipocal (`K/(x+S)+T`) curve: `factor` is `K` and `x_offset` is `S`, `y_offset` is `T`.
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
