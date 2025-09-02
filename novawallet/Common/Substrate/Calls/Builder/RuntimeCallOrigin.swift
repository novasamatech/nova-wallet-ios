import Foundation
import SubstrateSdk

enum RuntimeCallOrigin: Codable {
    case system(System)
    case unsupported(String)

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case "system":
            let model = try container.decode(System.self)
            self = .system(model)
        default:
            self = .unsupported(type)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .system(model):
            try container.encode("system")
            try container.encode(model)
        case let .unsupported(type):
            throw EncodingError.invalidValue(
                type,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported"
                )
            )
        }
    }
}

extension RuntimeCallOrigin {
    enum System: Codable {
        case root
        case signed(AccountId)
        case none
        case unsupported(String)

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case "Root":
                self = .root
            case "Signed":
                let accountId = try container.decode(BytesCodable.self).wrappedValue
                self = .signed(accountId)
            case "None":
                self = .none
            default:
                self = .unsupported(type)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            switch self {
            case .root:
                try container.encode("Root")
                try container.encode(JSON.null)
            case let .signed(accountId):
                try container.encode("Signed")
                try container.encode(BytesCodable(wrappedValue: accountId))
            case .none:
                try container.encode("None")
                try container.encode(JSON.null)
            case let .unsupported(type):
                throw EncodingError.invalidValue(
                    type,
                    EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: "Unsupported"
                    )
                )
            }
        }
    }
}
