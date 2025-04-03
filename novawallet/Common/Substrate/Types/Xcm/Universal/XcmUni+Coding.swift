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

extension Array: XcmUniEncodable where Element: XcmUniEncodable {
    func encode(to encoder: Encoder, version: Xcm.Version) throws {
        var container = encoder.unkeyedContainer()

        for element in self {
            let superEncoder = container.superEncoder()
            try element.encode(to: superEncoder, version: version)
        }
    }
}

extension Array: XcmUniDecodable where Element: XcmUniDecodable {
    init(from decoder: any Decoder, version: Xcm.Version) throws {
        var container = try decoder.unkeyedContainer()

        var elements: [Element] = []

        while !container.isAtEnd {
            let superDecoder = try container.superDecoder()
            let element = try Element(from: superDecoder, version: version)

            elements.append(element)
        }

        self.init(elements)
    }
}
