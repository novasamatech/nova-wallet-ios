import Foundation
import SubstrateSdk

struct XcmDynamicAsset: Decodable {
    let assetId: AssetModel.Id
    let xcmTransfers: [XcmDynamicAssetTransfer]
}
