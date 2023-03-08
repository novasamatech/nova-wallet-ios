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
}

struct BlockWeights: Decodable {
    enum CodingKeys: String, CodingKey {
        case maxBlock
        case perClass
    }

    @BlockchainWeight.WrappedRefTime var maxBlock: UInt64
    var perClass: PerDispatchClass

    var normalExtrinsicMaxWeight: UInt64? {
        perClass.normal.maxExtrinsic
    }
}

struct PerDispatchClass: Decodable {
    let normal: WeightsPerClass
    let operational: WeightsPerClass
    let mandatory: WeightsPerClass
}

struct WeightsPerClass: Decodable {
    enum CodingKeys: String, CodingKey {
        case maxExtrinsic
    }

    let maxExtrinsic: UInt64?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        maxExtrinsic = try container.decodeIfPresent(
            BlockchainWeight.WrappedRefTime.self,
            forKey: .maxExtrinsic
        )?.wrappedValue
    }
}
