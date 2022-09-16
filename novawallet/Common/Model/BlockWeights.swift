import Foundation
import SubstrateSdk

@propertyWrapper
struct ScaleStorageWeight: Decodable {
    let wrappedValue: UInt64

    typealias WeightV1 = StringScaleMapper<UInt64>

    struct WeightV1p5: Codable {
        var refTime: StringScaleMapper<UInt64>
    }

    init(wrappedValue: UInt64) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let compoundWeight = try? container.decode(WeightV1p5.self) {
            wrappedValue = compoundWeight.refTime.value
        } else {
            wrappedValue = try container.decode(WeightV1.self).value
        }
    }
}

struct BlockWeights: Decodable {
    @ScaleStorageWeight var maxBlock: UInt64
}
