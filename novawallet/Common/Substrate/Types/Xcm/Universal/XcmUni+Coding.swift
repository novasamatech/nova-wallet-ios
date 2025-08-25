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

// Native Dictionary doesn't support CodableWithConfiguration.
// The solution is to wrap the native dictionary and implement the coding
struct XcmUniDictionary<Value> {
    struct DynamicCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }

        var intValue: Int? { nil }
        init?(intValue _: Int) { nil }
    }

    let dict: [String: Value]
}

extension XcmUniDictionary: EncodableWithConfiguration where Value: EncodableWithConfiguration {
    typealias EncodingConfiguration = Value.EncodingConfiguration

    func encode(to encoder: any Encoder, configuration: Self.EncodingConfiguration) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)

        for (key, value) in dict {
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

extension XcmUniDictionary: DecodableWithConfiguration where Value: DecodableWithConfiguration {
    typealias DecodingConfiguration = Value.DecodingConfiguration

    init(from decoder: any Decoder, configuration: Value.DecodingConfiguration) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)

        var result: [String: Value] = [:]

        for codingKey in container.allKeys {
            let decodedValue = try container.decode(Value.self, forKey: codingKey, configuration: configuration)
            result[codingKey.stringValue] = decodedValue
        }

        dict = result
    }
}
