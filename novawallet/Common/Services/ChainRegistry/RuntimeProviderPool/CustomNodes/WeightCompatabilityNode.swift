import Foundation
import SubstrateSdk

/**
 *  This nodes overrides how Weight type is handled. Previous u64 type changed to
 *  a struct with a single u64 field (v1.5). From the scale encoding point of view
 *  nothing changes however encoder/decoder needs to be notified about concrete
 *  type to expect.
 *
 *  This node is used in WeightCompatabilityTypeMapper to override concrete type
 *  handling.
 */
final class WeightCompatabilityNode: Node {
    var typeName: String { "Weight" }
}

extension WeightCompatabilityNode: DynamicScaleCodable {
    func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendU64(json: value)
    }

    func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readU64()
    }
}
