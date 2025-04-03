import Foundation

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
