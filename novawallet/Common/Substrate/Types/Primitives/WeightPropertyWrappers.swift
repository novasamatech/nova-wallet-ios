import Foundation
import SubstrateSdk
import BigInt

extension Substrate {
    @propertyWrapper
    struct WeightDecodable: Decodable {
        let wrappedValue: Weight

        init(wrappedValue: Weight) {
            self.wrappedValue = wrappedValue
        }

        init(from decoder: Decoder) throws {
            let json = try JSON(from: decoder)

            // we need to take both camel and snake cases as we are using wrapper both for runtime and JSON PRC

            if let dict = json.dictValue {
                let refTimeJSON = dict["refTime"] ?? dict["ref_time"]

                guard let refTime = refTimeJSON?.toBigUInt() else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Could not decode ref time: \(dict)"
                        )
                    )
                }

                let proofSizeJSON = dict["proofSize"] ?? dict["proof_size"]

                if let proofSizeJSON {
                    guard let proofSize = proofSizeJSON.toBigUInt() else {
                        throw DecodingError.dataCorrupted(
                            DecodingError.Context(
                                codingPath: decoder.codingPath,
                                debugDescription: "Could not decode proof size: \(dict)"
                            )
                        )
                    }

                    wrappedValue = Weight(refTime: refTime, proofSize: proofSize)
                } else {
                    wrappedValue = Weight(refTime: refTime, proofSize: 0)
                }

            } else if let weight = json.toBigUInt() {
                wrappedValue = Weight(refTime: weight, proofSize: 0)
            } else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unexpected weight type"
                    )
                )
            }
        }
    }

    @propertyWrapper
    struct OptionalWeightDecodable: Decodable {
        let wrappedValue: Weight?

        init(wrappedValue: Weight?) {
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
}
