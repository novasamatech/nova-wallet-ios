import Foundation
import SubstrateSdk

protocol XcmUniEncodable: EncodableWithConfiguration where EncodingConfiguration == Xcm.Version {}

protocol XcmUniDecodable: DecodableWithConfiguration where DecodingConfiguration == Xcm.Version {}

typealias XcmUniCodable = XcmUniEncodable & XcmUniDecodable

extension XcmUni.Versioned: Encodable where Entity: XcmUniEncodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(version.rawName)
        try container.encode(entity, configuration: version)
    }
}

extension XcmUni.Versioned: Decodable where Entity: XcmUniDecodable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let rawVersion = try container.decode(String.self)

        guard let decodedVersion = Xcm.Version(rawName: rawVersion) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported version \(rawVersion)"
            )
        }

        version = decodedVersion

        entity = try container.decode(Entity.self, configuration: decodedVersion)
    }
}

extension Array: XcmUniCodable where Element: XcmUniCodable {}

// A helper CodingKey type that works with dynamic (string) keys.
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }

    var intValue: Int? { nil }
    init?(intValue _: Int) { nil }
}

extension Dictionary: EncodableWithConfiguration where Key == String,
    Value: EncodableWithConfiguration {
    public typealias EncodingConfiguration = Value.EncodingConfiguration

    public func encode(to encoder: any Encoder, configuration: Self.EncodingConfiguration) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)

        for (key, value) in self {
            guard let codingKey = DynamicCodingKey(stringValue: key) else {
                throw EncodingError.invalidValue(
                    key,
                    EncodingError.Context(
                        codingPath: container.codingPath,
                        debugDescription: "Unable to create coding key for \(key)"
                    )
                )
            }

            try container.encode(value, forKey: codingKey, configuration: configuration)
        }
    }
}

extension Dictionary: DecodableWithConfiguration where Key == String,
    Value: DecodableWithConfiguration {
    public typealias DecodingConfiguration = Value.DecodingConfiguration

    public init(from decoder: any Decoder, configuration: Value.DecodingConfiguration) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        self.init()

        // Iterate over all keys in the container.
        for codingKey in container.allKeys {
            let decodedKey = codingKey.stringValue

            // Decode the value using Value's configuration-aware decoder.
            let decodedValue = try container.decode(Value.self, forKey: codingKey, configuration: configuration)
            self[decodedKey] = decodedValue
        }
    }
}
