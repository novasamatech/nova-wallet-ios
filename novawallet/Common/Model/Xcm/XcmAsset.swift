import Foundation
import SubstrateSdk

struct XcmAsset: Decodable {
    let assetId: AssetModel.Id
    let assetLocation: String
    let assetLocationPath: XcmAsset.Location
}

extension XcmAsset {
    enum LocationType: String, Decodable {
        case absolute
        case relative
        case concrete
    }

    struct Location: Decodable {
        let type: LocationType
        let path: JSON?
    }
}
