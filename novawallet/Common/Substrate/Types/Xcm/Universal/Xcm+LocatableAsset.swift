import Foundation

extension XcmUni {
    struct LocatableAsset: Equatable {
        let location: RelativeLocation
        let assetId: AssetId
    }
}

extension XcmUni.LocatableAsset: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case location
        case assetId
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        location = try container.decode(
            XcmUni.RelativeLocation.self,
            forKey: .location,
            configuration: configuration
        )

        assetId = try container.decode(
            XcmUni.AssetId.self,
            forKey: .assetId,
            configuration: configuration
        )
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(location, forKey: .location, configuration: configuration)
        try container.encode(assetId, forKey: .assetId, configuration: configuration)
    }
}
