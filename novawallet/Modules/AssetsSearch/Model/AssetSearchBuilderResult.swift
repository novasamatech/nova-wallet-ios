import Foundation
import Operation_iOS

struct AssetSearchBuilderResult {
    let chainGroups: [AssetListChainGroupModel]
    let assetGroups: [AssetListAssetGroupModel]
    let groupListsByChain: [ChainModel.Id: [AssetListAssetModel]]
    let groupListsByAsset: [AssetModel.Symbol: [AssetListAssetModel]]
    let state: AssetListState

    init(
        chainGroups: [AssetListChainGroupModel],
        assetGroups: [AssetListAssetGroupModel],
        groupListsByChain: [ChainModel.Id: [AssetListAssetModel]],
        groupListsByAsset: [AssetModel.Symbol: [AssetListAssetModel]],
        state: AssetListState
    ) {
        self.chainGroups = chainGroups
        self.assetGroups = assetGroups
        self.groupListsByChain = groupListsByChain
        self.groupListsByAsset = groupListsByAsset
        self.state = state
    }
}
