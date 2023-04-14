struct RemoteEquilibriumSubscriptionInfo {
    let accountId: AccountId
    let chain: ChainModel
    let equilibriumAssetIds: Set<AssetModel.Id>
}

struct EquilibriumAssetId: Hashable {
    let localAssetId: AssetModel.Id
    let extrenalAssetId: AssetModel.Id
}
