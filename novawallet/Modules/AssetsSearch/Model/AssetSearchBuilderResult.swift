import Foundation
import Operation_iOS

struct AssetSearchBuilderResult {
    let groups: ListDifferenceCalculator<AssetListGroupModel>
    let groupLists: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>]
    let state: AssetListState
}
