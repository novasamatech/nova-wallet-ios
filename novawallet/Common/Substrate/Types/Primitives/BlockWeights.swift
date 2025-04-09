import Foundation
import SubstrateSdk
import BigInt

extension Substrate {
    typealias WeightV1 = StringScaleMapper<UInt64>

    struct WeightV1P5: Codable {
        @StringCodable var refTime: UInt64
    }

    struct WeightV2: Codable {
        @StringCodable var refTime: BigUInt
        @StringCodable var proofSize: BigUInt
    }

    @propertyWrapper
    struct WrappedRefTime: Decodable {
        let wrappedValue: UInt64

        init(wrappedValue: UInt64) {
            self.wrappedValue = wrappedValue
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let weight = try? container.decode(WeightV1P5.self) {
                wrappedValue = weight.refTime
            } else {
                wrappedValue = try container.decode(WeightV1.self).value
            }
        }
    }

    @propertyWrapper
    struct WeightDecodable: Decodable {
        let wrappedValue: WeightV2

        init(wrappedValue: WeightV2) {
            self.wrappedValue = wrappedValue
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let weightV2 = try? container.decode(WeightV2.self) {
                wrappedValue = weightV2
            } else if let weight1p5 = try? container.decode(WeightV1P5.self) {
                wrappedValue = .init(refTime: BigUInt(weight1p5.refTime), proofSize: 0)
            } else {
                let weightV1 = try container.decode(WeightV1.self).value
                wrappedValue = .init(refTime: BigUInt(weightV1), proofSize: 0)
            }
        }
    }

    @propertyWrapper
    struct OptionalWeightDecodable: Decodable {
        let wrappedValue: WeightV2?

        init(wrappedValue: WeightV2?) {
            self.wrappedValue = wrappedValue
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if container.decodeNil() {
                wrappedValue = nil
            } else {
                wrappedValue = try container.decode(WeightDecodable.self).wrappedValue
            }
        }
    }

    struct BlockWeights: Decodable {
        @Substrate.WeightDecodable var maxBlock: WeightV2
        let perClass: PerDispatchClass<WeightsPerClass>

        var normalExtrinsicMaxWeight: WeightV2? {
            perClass.normal.maxExtrinsic
        }
    }

    struct PerDispatchClass<T: Decodable>: Decodable {
        let normal: T
        let operational: T
        let mandatory: T
    }

    struct WeightsPerClass: Decodable {
        @OptionalWeightDecodable var maxExtrinsic: WeightV2?
    }

    typealias PerDispatchClassWithWeight = PerDispatchClassWithWeight<WeightV2>
}
