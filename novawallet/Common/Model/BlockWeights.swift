import Foundation
import SubstrateSdk
import BigInt

enum BlockchainWeight {
    typealias WeightV1 = StringScaleMapper<UInt64>

    struct WeightV1P5: Codable {
        @StringCodable var refTime: UInt64
    }

    struct WeightV2: Codable {
        @StringCodable var refTime: BigUInt
        @StringCodable var proofSize: UInt64
    }

    @propertyWrapper
    struct WrappedRefTime: Decodable {
        let wrappedValue: UInt64

        init(wrappedValue: UInt64) {
            self.wrappedValue = wrappedValue
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let weight = try? container.decode(BlockchainWeight.WeightV1P5.self) {
                wrappedValue = weight.refTime
            } else {
                wrappedValue = try container.decode(BlockchainWeight.WeightV1.self).value
            }
        }
    }

    @propertyWrapper
    struct OptionWrappedRefTime: Decodable {
        let wrappedValue: UInt64?

        init(wrappedValue: UInt64?) {
            self.wrappedValue = wrappedValue
        }

        init(from decoder: Decoder) throws {
            wrappedValue = try WrappedRefTime(from: decoder).wrappedValue
        }
    }
}

struct BlockWeights: Decodable {
    enum CodingKeys: String, CodingKey {
        case maxBlock
        case perClass
    }

    @BlockchainWeight.WrappedRefTime var maxBlock: UInt64
    var perClass: PerDispatchClass

    var normalExtrinsicMaxWeight: UInt64? {
        switch perClass {
        case let .normal(weightsPerClass):
            return weightsPerClass.maxExtrinsic
        case .operational, .mandatory, .unknown:
            return nil
        }
    }
}

enum PerDispatchClass: Decodable {
    case normal(WeightsPerClass)
    case operational(WeightsPerClass)
    case mandatory(WeightsPerClass)
    case unknown

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)
        let value = try container.decode(WeightsPerClass.self)

        switch type {
        case "Normal":
            self = .normal(value)
        case "Operational":
            self = .operational(value)
        case "Mandatory":
            self = .mandatory(value)
        default:
            self = .unknown
        }
    }

    var maxExtrinsic: UInt64? {
        switch self {
        case let .normal(weightsPerClass):
            return weightsPerClass.maxExtrinsic
        case let .operational(weightsPerClass):
            return weightsPerClass.maxExtrinsic
        case let .mandatory(weightsPerClass):
            return weightsPerClass.maxExtrinsic
        case .unknown:
            return nil
        }
    }
}

struct WeightsPerClass: Decodable {
    enum CodingKeys: String, CodingKey {
        case maxExtrinsic
    }

    @BlockchainWeight.OptionWrappedRefTime var maxExtrinsic: UInt64?
}
