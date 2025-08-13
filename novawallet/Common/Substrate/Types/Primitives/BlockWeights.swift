import Foundation
import SubstrateSdk
import BigInt

extension Substrate {
    typealias WeightV1 = StringScaleMapper<UInt64>

    struct WeightV1P5: Codable, Equatable {
        @StringCodable var refTime: BigUInt
    }

    struct WeightV2: Codable, Equatable {
        @StringCodable var refTime: BigUInt
        @StringCodable var proofSize: BigUInt
    }

    typealias Weight = WeightV2

    struct BlockWeights: Decodable {
        @Substrate.WeightDecodable var maxBlock: Weight
        let perClass: PerDispatchClass<WeightsPerClass>
    }

    struct PerDispatchClass<T: Decodable>: Decodable {
        let normal: T
        let operational: T
        let mandatory: T
    }

    struct WeightsPerClass: Decodable {
        @OptionalWeightDecodable var maxExtrinsic: Weight?
        @OptionalWeightDecodable var maxTotal: Weight?
    }

    typealias PerDispatchClassWithWeight = PerDispatchClass<Weight>
}

extension Substrate.PerDispatchClassWithWeight {
    var totalWeight: Substrate.Weight {
        normal + operational + mandatory
    }
}
