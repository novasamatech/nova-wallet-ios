import Foundation
import Operation_iOS

struct ChainAssetViewModel: Identifiable {
    var identifier: String {
        chainAssetId.stringValue
    }

    let chainAssetId: ChainAssetId

    let networkViewModel: NetworkViewModel
    let assetViewModel: AssetViewModel
}
