import Foundation
import SubstrateSdk

typealias WeightV1 = UInt64

struct WeightV1p5: Codable {
    enum CodingKeys: String, CodingKey {
        case refTime = "ref_time"
    }

    let refTime: UInt64
}

struct RuntimeDispatchInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case dispatchClass = "class"
        case fee = "partialFee"
        case weight
    }

    let dispatchClass: String
    let fee: String
    let weight: UInt64

    init(
        dispatchClass: String,
        fee: String,
        weight: UInt64
    ) {
        self.dispatchClass = dispatchClass
        self.fee = fee
        self.weight = weight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        dispatchClass = try container.decode(String.self, forKey: .dispatchClass)
        fee = try container.decode(String.self, forKey: .fee)

        if let compoundWeight = try? container.decode(WeightV1p5.self, forKey: .weight) {
            weight = compoundWeight.refTime
        } else {
            weight = try container.decode(WeightV1.self, forKey: .weight)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(dispatchClass, forKey: .dispatchClass)
        try container.encode(fee, forKey: .fee)

        try container.encode(WeightV1p5(refTime: weight), forKey: .weight)
    }
}
