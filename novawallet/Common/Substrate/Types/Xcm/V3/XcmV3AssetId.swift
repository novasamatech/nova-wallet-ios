import Foundation
import SubstrateSdk

extension XcmV3 {
    enum AssetId: Equatable, Codable {
        case concrete(XcmV3.Multilocation)
        case abstract(Data)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .concrete(multilocation):
                try container.encode("Concrete")
                try container.encode(multilocation)
            case let .abstract(data):
                try container.encode("Abstract")
                try container.encode(BytesCodable(wrappedValue: data))
            }
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Concrete":
                let multilocation = try container.decode(XcmV3.Multilocation.self)
                self = .concrete(multilocation)
            case "Abstract":
                let data = try container.decode(BytesCodable.self).wrappedValue
                self = .abstract(data)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unsupported type: \(type)"
                    )
                )
            }
        }
    }
}
