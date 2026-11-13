import Foundation

struct SwapTokenSelectItem {
    let chainAsset: ChainAsset
    let balance: Decimal?
    let value: Decimal?
    let priceData: PriceData?

    var hasBalance: Bool {
        (balance ?? 0) > 0
    }
}

struct SwapTokenSelectList {
    let yourTokens: [SwapTokenSelectItem]
    let otherTokens: [SwapTokenSelectItem]
    let notSwappable: [SwapTokenSelectItem]
    let balancesLoading: Bool
    let networks: [ChainModel]

    var isEmpty: Bool {
        yourTokens.isEmpty && otherTokens.isEmpty && notSwappable.isEmpty && !balancesLoading
    }
}

struct SwapTokenSelectListParams {
    let side: SwapTokenSelectionSide
    let context: SwapTokenSelectionContext
    let assetList: AssetListModel
    let routeUniverse: Set<ChainAssetId>?
    let swappable: Set<ChainAssetId>?
    let query: String
    let networkFilter: Set<ChainModel.Id>
    let showsPendingBalances: Bool
}
