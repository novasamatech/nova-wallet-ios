struct LocksViewInput {
    let prices: [ChainAssetId: PriceData]
    let balances: [AssetBalance]
    let chains: [ChainModel.Id: ChainModel]
    let locks: [AssetLock]
    let holds: [AssetHold]
    let externalBalances: [ChainAssetId: [ExternalAssetBalance]]
}
