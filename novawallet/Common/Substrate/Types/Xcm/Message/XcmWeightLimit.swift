import Foundation
import SubstrateSdk

extension Xcm {
    enum WeightLimit: Codable {
        static let unlimitedField = "Unlimited"
        static let limitedField = "Limited"

        case unlimited
        case limited(weight: UInt64)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .unlimited:
                try container.encode(Self.unlimitedField)
            case let .limited(weight):
                try container.encode(Self.limitedField)
                try container.encode(StringScaleMapper(value: weight))
            }
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case Self.unlimitedField:
                self = .unlimited
            case Self.limitedField:
                let weight = try container.decode(StringScaleMapper<UInt64>.self).value
                self = .limited(weight: weight)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected type"
                )
            }
        }
    }
}
