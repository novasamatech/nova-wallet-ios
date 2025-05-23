import Foundation

// swiftlint:disable identifier_name
enum XcmVersionedLocatableAsset: Equatable, Codable {
    case V3(XcmV3.LocatableAsset)
    case V4(XcmV4.LocatableAsset)
    case V5(XcmV5.LocatableAsset)

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        let version = try container.decode(String.self)

        switch version {
        case "V3":
            let asset = try container.decode(XcmV3.LocatableAsset.self)
            self = .V3(asset)
        case "V4":
            let asset = try container.decode(XcmV4.LocatableAsset.self)
            self = .V4(asset)
        case "V5":
            let asset = try container.decode(XcmV5.LocatableAsset.self)
            self = .V5(asset)
        default:
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported version: \(version)"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .V3(asset):
            try container.encode("V3")
            try container.encode(asset)
        case let .V4(asset):
            try container.encode("V4")
            try container.encode(asset)
        case let .V5(asset):
            try container.encode("V5")
            try container.encode(asset)
        }
    }
}

extension XcmVersionedLocatableAsset {
    var location: XcmV3.Multilocation {
        switch self {
        case let .V3(locatableAsset):
            return locatableAsset.location
        case let .V4(locatableAsset):
            return locatableAsset.location
        case let .V5(locatableAsset):
            return locatableAsset.location
        }
    }

    var assetId: XcmV3.Multilocation? {
        switch self {
        case let .V3(locatableAsset):
            return locatableAsset.assetId.toMultilocation()
        case let .V4(locatableAsset):
            return locatableAsset.assetId
        case let .V5(locatableAsset):
            return locatableAsset.assetId
        }
    }
}

extension XcmV3.AssetId {
    func toMultilocation() -> XcmV3.Multilocation? {
        switch self {
        case let .concrete(multilocation):
            return multilocation
        case .abstract:
            return nil
        }
    }
}
