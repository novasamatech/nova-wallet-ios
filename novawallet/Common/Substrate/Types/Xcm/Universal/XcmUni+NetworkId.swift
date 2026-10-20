import Foundation
import SubstrateSdk

extension XcmUni {
    enum NetworkId: Equatable {
        case any
        case ethereum(chainId: UInt64)
        case other(RawName, RawValue)
    }
}

extension XcmUni.NetworkId {
    static let anyField = "Any"
    static let ethereumField = "Ethereum"

    enum RawPathKey: String {
        case ethereum
        case chainId
    }

    static func createWithRawPath(_ path: JSON) throws -> XcmUni.NetworkId {
        guard
            let fields = path.dictValue,
            fields.count == 1,
            let ethereum = fields[RawPathKey.ethereum.rawValue]?.dictValue else {
            throw XcmUni.AbsoluteLocation.RawPathError.unsupportedConsensus(path)
        }

        let chainIdValue = ethereum[RawPathKey.chainId.rawValue]

        if let chainId = chainIdValue?.unsignedIntValue {
            return .ethereum(chainId: chainId)
        }

        if let chainIdString = chainIdValue?.stringValue, let chainId = UInt64(chainIdString) {
            return .ethereum(chainId: chainId)
        }

        throw XcmUni.AbsoluteLocation.RawPathError.unsupportedConsensus(path)
    }

    struct EthereumValue: Codable {
        let chainId: StringScaleMapper<UInt64>
    }

    static func unsupportedVersionError(
        _ version: Xcm.Version,
        entity: String,
        codingPath: [CodingKey]
    ) -> EncodingError {
        EncodingError.invalidValue(
            version,
            .init(codingPath: codingPath, debugDescription: "\(entity) is available from XCM V3")
        )
    }
}

extension XcmUni.NetworkId: XcmUniCodable {
    init(from decoder: any Decoder, configuration _: Xcm.Version) throws {
        let singleContainer = try decoder.singleValueContainer()

        if singleContainer.decodeNil() {
            self = .any
            return
        }

        var unkeyedContainer = try decoder.unkeyedContainer()

        let type = try unkeyedContainer.decode(String.self)

        switch type {
        case Self.anyField:
            self = .any
        case Self.ethereumField:
            let value = try unkeyedContainer.decode(EthereumValue.self)
            self = .ethereum(chainId: value.chainId.value)
        default:
            let value = try unkeyedContainer.decode(XcmUni.RawValue.self)
            self = .other(type, value)
        }
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        switch self {
        case .any:
            try encodeAny(to: encoder, configuration: configuration)
        case let .ethereum(chainId):
            switch configuration {
            case .V0, .V1, .V2:
                throw Self.unsupportedVersionError(
                    configuration,
                    entity: "NetworkId.Ethereum",
                    codingPath: encoder.codingPath
                )
            case .V3, .V4, .V5:
                var unkeyedContainer = encoder.unkeyedContainer()
                try unkeyedContainer.encode(Self.ethereumField)
                try unkeyedContainer.encode(EthereumValue(chainId: StringScaleMapper(value: chainId)))
            }
        case let .other(rawName, rawValue):
            var unkeyedContainer = encoder.unkeyedContainer()
            try unkeyedContainer.encode(rawName)
            try unkeyedContainer.encode(rawValue)
        }
    }

    func encodeAny(to encoder: any Encoder, configuration: Xcm.Version) throws {
        switch configuration {
        case .V0, .V1, .V2:
            var container = encoder.unkeyedContainer()
            try container.encode(Self.anyField)
            try container.encode(JSON.null)
        case .V3, .V4, .V5:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}
