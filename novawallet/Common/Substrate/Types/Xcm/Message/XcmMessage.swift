import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum Message: Codable {
        case V2([Xcm.Instruction])
        case V3([XcmV3.Instruction])
        case V4([XcmV4.Instruction])

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V2(instructions):
                try container.encode("V2")
                try container.encode(instructions)
            case let .V3(instructions):
                try container.encode("V3")
                try container.encode(instructions)
            case let .V4(instructions):
                try container.encode("V4")
                try container.encode(instructions)
            }
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let version = try container.decode(String.self)

            switch version {
            case "V2":
                let instructions = try container.decode([Xcm.Instruction].self)
                self = .V2(instructions)
            case "V3":
                let instructions = try container.decode([XcmV3.Instruction].self)
                self = .V3(instructions)
            case "V4":
                let instructions = try container.decode([XcmV4.Instruction].self)
                self = .V4(instructions)
            default:
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported version \(version)"
                    )
                )
            }
        }

        var instructionsCount: Int {
            switch self {
            case let .V2(instructions):
                return instructions.count
            case let .V3(instructions):
                return instructions.count
            case let .V4(instructions):
                return instructions.count
            }
        }
    }
    // swiftlint:enable identifier_name
}
