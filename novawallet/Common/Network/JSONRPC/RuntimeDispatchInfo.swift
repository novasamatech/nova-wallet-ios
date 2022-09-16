import Foundation
import SubstrateSdk

@propertyWrapper
struct FeeWeight: Codable {
    let wrappedValue: UInt64

    typealias WeightV1 = UInt64

    struct WeightV1p5: Codable {
        enum CodingKeys: String, CodingKey {
            case refTime = "ref_time"
        }

        let refTime: UInt64
    }

    init(wrappedValue: UInt64) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let compoundWeight = try? container.decode(WeightV1p5.self) {
            wrappedValue = compoundWeight.refTime
        } else {
            wrappedValue = try container.decode(WeightV1.self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(WeightV1p5(refTime: wrappedValue))
    }
}

struct RuntimeDispatchInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case dispatchClass = "class"
        case fee = "partialFee"
        case weight
    }

    let dispatchClass: String
    let fee: String
    @FeeWeight var weight: UInt64
}
