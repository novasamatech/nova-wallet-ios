import Foundation
import Operation_iOS

struct AssetSearchBuilderResult {
    let chainGroups: [AssetListChainGroupModel]
    let assetGroups: [AssetListAssetGroupModel]
    let groupListsByChain: [ChainModel.Id: [AssetListAssetModel]]
    let groupListsByAsset: [AssetModel.Symbol: [AssetListAssetModel]]
    let state: AssetListState
}
