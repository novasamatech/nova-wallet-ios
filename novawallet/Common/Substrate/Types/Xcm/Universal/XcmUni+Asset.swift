import Foundation
import SubstrateSdk
import BigInt

extension XcmUni {
    struct AssetId: Equatable {
        let location: RelativeLocation
    }

    enum WildAsset: Equatable {
        case all
        case allCounted(UInt32)
        case other(RawName, RawValue)
    }

    typealias AssetInstance = RawValue

    enum Fungibility: Equatable {
        case fungible(Balance)
        case nonFungible(AssetInstance)
    }

    struct Asset: Equatable {
        let assetId: AssetId
        let fun: Fungibility

        init(location: RelativeLocation, amount: BigUInt) {
            assetId = AssetId(location: location)

            // starting from xcmV3 zero amount is prohibited
            fun = .fungible(max(amount, 1))
        }

        init(assetId: AssetId, amount: BigUInt) {
            self.assetId = assetId

            // starting from xcmV3 zero amount is prohibited
            fun = .fungible(max(amount, 1))
        }
    }

    typealias Assets = [Asset]

    enum AssetFilter: Equatable {
        case definite(Assets)
        case wild(WildAsset)
    }
}

private extension XcmUni.AssetId {
    init(fromPreV4 decoder: any Decoder, configuration: Xcm.Version) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case "Concrete":
            location = try container.decode(
                XcmUni.RelativeLocation.self,
                configuration: configuration
            )
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported asset id type \(type)"
                )
            )
        }
    }

    init(fromPostV4 decoder: any Decoder, configuration: Xcm.Version) throws {
        location = try XcmUni.RelativeLocation(from: decoder, configuration: configuration)
    }

    func encodePreV4(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.unkeyedContainer()

        try container.encode("Concrete")
        try container.encode(location, configuration: configuration)
    }
}

extension XcmUni.AssetId: XcmUniCodable {
    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        switch configuration {
        case .V0, .V1, .V2, .V3:
            try self.init(fromPreV4: decoder, configuration: configuration)
        case .V4, .V5:
            try self.init(fromPostV4: decoder, configuration: configuration)
        }
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        switch configuration {
        case .V0, .V1, .V2, .V3:
            try encodePreV4(to: encoder, configuration: configuration)
        case .V4, .V5:
            try location.encode(to: encoder, configuration: configuration)
        }
    }
}

extension XcmUni.Fungibility: Codable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case "Fungible":
            let amount = try container.decode(StringScaleMapper<Balance>.self).value
            self = .fungible(amount)
        case "NonFungible":
            let assetInstance = try container.decode(XcmUni.AssetInstance.self)
            self = .nonFungible(assetInstance)
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Unknown fungibility \(type)"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .fungible(amount):
            try container.encode("Fungible")
            try container.encode(StringScaleMapper(value: amount))
        case let .nonFungible(assetInstance):
            try container.encode("NonFungible")
            try container.encode(assetInstance)
        }
    }
}

extension XcmUni.Asset: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case assetId = "id"
        case fun
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        assetId = try container.decode(
            XcmUni.AssetId.self,
            forKey: .assetId,
            configuration: configuration
        )

        fun = try container.decode(
            XcmUni.Fungibility.self,
            forKey: .fun
        )
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(
            assetId,
            forKey: .assetId,
            configuration: configuration
        )

        try container.encode(fun, forKey: .fun)
    }
}

extension XcmUni.WildAsset: Codable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case "All":
            self = .all
        case "AllCounted":
            let value = try container.decode(StringScaleMapper<UInt32>.self).value
            self = .allCounted(value)
        default:
            let value = try container.decode(XcmUni.RawValue.self)
            self = .other(type, value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case .all:
            try container.encode("All")
            try container.encode(JSON.null)
        case let .allCounted(value):
            try container.encode("AllCounted")
            try container.encode(StringScaleMapper(value: value))
        case let .other(type, value):
            try container.encode(type)
            try container.encode(value)
        }
    }
}

extension XcmUni.AssetFilter: XcmUniCodable {
    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case "Definite":
            let value = try container.decode(XcmUni.Assets.self, configuration: configuration)
            self = .definite(value)
        case "Wild":
            let value = try container.decode(XcmUni.WildAsset.self)
            self = .wild(value)
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported filter \(type)"
                )
            )
        }
    }

    func encode(to encoder: Encoder, configuration: Xcm.Version) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .definite(multiassets):
            try container.encode("Definite")
            try container.encode(multiassets, configuration: configuration)
        case let .wild(wildMultiasset):
            try container.encode("Wild")
            try container.encode(wildMultiasset)
        }
    }
}
