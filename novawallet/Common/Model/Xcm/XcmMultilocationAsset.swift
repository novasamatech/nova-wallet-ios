import Foundation

struct XcmMultilocationAsset {
    let location: Xcm.VersionedMultilocation
    let asset: Xcm.VersionedMultiasset
}

struct XcmMultilocationAssetVersion {
    let multiLocation: Xcm.Version?
    let multiAssets: Xcm.Version?
}
