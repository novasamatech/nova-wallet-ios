import Foundation

extension Xcm {
    // swiftlint:disable identifier_name
    enum VersionedMultiasset: Codable {
        case V1(Xcm.Multiasset)
        case V2(Xcm.Multiasset)
        case V3(XcmV3.Multiasset)
        case V4(XcmV4.Multiasset)

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multiasset):
                try container.encode("V1")
                try container.encode(multiasset)
            case let .V2(multiasset):
                try container.encode("V2")
                try container.encode(multiasset)
            case let .V3(multiasset):
                try container.encode("V3")
                try container.encode(multiasset)
            case let .V4(multiasset):
                try container.encode("V4")
                try container.encode(multiasset)
            }
        }

        init(from _: Decoder) throws {
            fatalError("Decoding unsupported")
        }
    }

    enum VersionedMultiassets: Codable {
        case V1([Xcm.Multiasset])
        case V2([Xcm.Multiasset])
        case V3([XcmV3.Multiasset])
        case V4([XcmV4.Multiasset])

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .V1(multiassets):
                try container.encode("V1")
                try container.encode(multiassets)
            case let .V2(multiassets):
                try container.encode("V2")
                try container.encode(multiassets)
            case let .V3(multiassets):
                try container.encode("V3")
                try container.encode(multiassets)
            case let .V4(multiassets):
                try container.encode("V4")
                try container.encode(multiassets)
            }
        }

        init(from _: Decoder) throws {
            fatalError("Decoding unsupported")
        }

        init(versionedMultiasset: Xcm.VersionedMultiasset) {
            switch versionedMultiasset {
            case let .V1(multiasset):
                self = .V1([multiasset])
            case let .V2(multiasset):
                self = .V2([multiasset])
            case let .V3(multiasset):
                self = .V3([multiasset])
            case let .V4(multiasset):
                self = .V4([multiasset])
            }
        }
    }

    // swiftlint:enable identifier_name
}

extension Xcm.VersionedMultiassets {
    static func versionedMultiassets(
        for version: Xcm.Version?,
        multiAssets: [Xcm.Multiasset]
    ) -> Xcm.VersionedMultiassets {
        guard let version = version else {
            return .V2(multiAssets)
        }

        if version <= .V1 {
            return .V1(multiAssets)
        } else {
            return .V2(multiAssets)
        }
    }
}

extension Xcm.VersionedMultiasset {
    static func versionedMultiasset(
        for version: Xcm.Version?,
        multiAsset: Xcm.Multiasset
    ) -> Xcm.VersionedMultiasset {
        guard let version = version else {
            return .V2(multiAsset)
        }

        if version <= .V1 {
            return .V1(multiAsset)
        } else {
            return .V2(multiAsset)
        }
    }
}
