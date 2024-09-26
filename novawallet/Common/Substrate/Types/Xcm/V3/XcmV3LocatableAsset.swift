import Foundation

extension XcmV3 {
    struct LocatableAsset: Equatable, Codable {
        let location: XcmV3.Multilocation
        let assetId: XcmV3.AssetId
    }
}
