import Foundation
import SubstrateSdk

enum DAppParsedCall: Encodable {
    case raw(bytes: Data)
    case callable(value: RuntimeCall<JSON>)

    func accept(builder: ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol {
        switch self {
        case let .raw(bytes):
            return try builder.adding(rawCall: bytes)
        case let .callable(value):
            return try builder.adding(call: value)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .raw(bytes):
            try bytes.toHex(includePrefix: true).encode(to: encoder)
        case let .callable(value):
            try value.encode(to: encoder)
        }
    }
}
