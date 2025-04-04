import Foundation
import SubstrateSdk

extension Xcm {
    enum WeightLimitFields {
        static let unlimited = "Unlimited"
        static let limited = "Limited"
    }

    enum WeightLimit<T>: Codable where T: Codable {
        case unlimited
        case limited(weight: T)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case .unlimited:
                try container.encode(WeightLimitFields.unlimited)
                try container.encode(JSON.null)
            case let .limited(weight):
                try container.encode(WeightLimitFields.limited)
                try container.encode(weight)
            }
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case WeightLimitFields.unlimited:
                self = .unlimited
            case WeightLimitFields.limited:
                let weight = try container.decode(T.self)
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

extension Xcm.WeightLimit: Equatable where T: Equatable {}

extension Xcm.WeightLimit {
    func map<U: Codable>(_ transform: (T) throws -> U) rethrows -> Xcm.WeightLimit<U> {
        switch self {
        case let .limited(weight):
            return .limited(weight: try transform(weight))
        case .unlimited:
            return .unlimited
        }
    }
}
