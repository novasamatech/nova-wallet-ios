struct RemoteEquilibriumSubscriptionInfo {
    let accountId: AccountId
    let chain: ChainModel
    let assets: [EquilibriumAssetId]
}

typealias EquilibriumAssetId = UInt64
