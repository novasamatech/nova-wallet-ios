import Foundation

extension XcmV4 {
    struct LocatableAsset: Equatable, Codable {
        let location: XcmV3.Multilocation
        let assetId: XcmV3.Multilocation
    }
}
