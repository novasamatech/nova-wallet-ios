import SubstrateSdk
import Foundation

@propertyWrapper
struct AsciiDataString: Equatable {
    var wrappedValue: String
}

extension AsciiDataString: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let data = try container.decode(BytesCodable.self).wrappedValue
        guard let decodedString = String(data: data, encoding: .ascii) else {
            throw DecodingError
                .dataCorrupted(.init(codingPath: container.codingPath, debugDescription: ""))
        }
        wrappedValue = decodedString
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let data = wrappedValue.data(using: .ascii) else {
            throw DecodingError
                .dataCorrupted(.init(codingPath: container.codingPath, debugDescription: ""))
        }
        let bytes = data.map { StringScaleMapper(value: $0) }
        try container.encode(bytes)
    }
}
