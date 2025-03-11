import Foundation

struct XcmMultilocationAsset {
    let location: Xcm.VersionedMultilocation
    let asset: Xcm.VersionedMultiasset
}

// TODO: Have single version for xcm
struct XcmMultilocationAssetVersion {
    let multiLocation: Xcm.Version?
    let multiAssets: Xcm.Version?
}
