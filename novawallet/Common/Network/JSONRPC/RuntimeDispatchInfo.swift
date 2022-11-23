import Foundation
import SubstrateSdk
import BigInt

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

/// This struct is used to query fee vi api
struct RuntimeDispatchInfo: Codable {
    enum CodingKeys: String, CodingKey {
        case fee = "partialFee"
        case weight
    }

    let fee: String
    @FeeWeight var weight: UInt64

    init(fee: String, weight: UInt64) {
        self.fee = fee
        _weight = FeeWeight(wrappedValue: weight)
    }
}

/// This struct is used to query fee via state call
struct RemoteRuntimeDispatchInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case fee = "partialFee"
        case weight
    }

    let fee: BigUInt
    let weight: UInt64

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        fee = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .fee).value

        if let remoteWeight = try? container.decode(BlockchainWeight.WeightV1P5.self, forKey: .weight) {
            weight = remoteWeight.refTime
        } else {
            weight = try container.decode(BlockchainWeight.WeightV1.self, forKey: .weight).value
        }
    }
}
