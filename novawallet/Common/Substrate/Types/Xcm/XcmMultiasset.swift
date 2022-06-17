import Foundation
import BigInt
import SubstrateSdk

extension Xcm {
    enum Multiasset: Encodable {
        case сoncreteFungible(location: Multilocation, amount: BigUInt)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .сoncreteFungible(location, amount):
                try container.encode("ConcreteFungible")
                try container.encode(location)
                try container.encode(StringScaleMapper(value: amount))
            }
        }
    }
}
