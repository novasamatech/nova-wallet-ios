import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum Message: Codable {
        case V2([Xcm.Instruction])

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V2(instructions):
                try container.encode("V2")
                try container.encode(instructions)
            }
        }

        init(from _: Decoder) throws {
            fatalError("Decoding unsupported")
        }

        var instructionsCount: Int {
            switch self {
            case .V2(let instructions):
                return instructions.count
            }
        }
    }
    // swiftlint:enable identifier_name
}
