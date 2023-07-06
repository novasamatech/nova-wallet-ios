import Foundation
import RobinHood

struct AssetSearchBuilderResult {
    let groups: ListDifferenceCalculator<AssetListGroupModel>
    let groupLists: [ChainModel.Id: ListDifferenceCalculator<AssetListAssetModel>]
    let state: AssetListState
}
