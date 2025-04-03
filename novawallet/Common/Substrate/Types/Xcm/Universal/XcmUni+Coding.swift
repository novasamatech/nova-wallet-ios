import Foundation

protocol XcmUniDecodable {
    init(from decoder: Decoder, version: Xcm.Version) throws
}

protocol XcmUniEncodable {
    func encode(to encoder: Encoder, version: Xcm.Version) throws
}

typealias XcmUniCodable = XcmUniDecodable & XcmUniEncodable

extension XcmUni.Versioned: Encodable where Entity: XcmUniEncodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        try container.encode(version.rawName)

        let superEncoder = container.superEncoder()
        try entity.encode(to: superEncoder, version: version)
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

        let superDecoder = try container.superDecoder()
        entity = try Entity(from: superDecoder, version: decodedVersion)
    }
}
