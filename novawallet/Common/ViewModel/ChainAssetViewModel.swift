import Foundation
import Operation_iOS

struct ChainAssetViewModel: Identifiable {
    var identifier: String {
        chainAssetId.stringValue
    }

    var assetName: String {
        assetViewModel.name ?? networkViewModel.name
    }

    let chainAssetId: ChainAssetId

    let networkViewModel: NetworkViewModel
    let assetViewModel: AssetViewModel
}
