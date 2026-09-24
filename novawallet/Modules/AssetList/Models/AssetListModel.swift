import BigInt

typealias AssetListModelObservable = Observable<NotEqualWrapper<AssetListModel>>

struct AssetListModel {
    let priceResult: Result<[ChainAssetId: PriceData], Error>?
    let allChains: [ChainModel.Id: ChainModel]
    let balances: [ChainAssetId: Result<AssetBalance, Error>]
    let externalBalances: Result<[ChainAssetId: [ExternalAssetBalance]], Error>?
    let chainsIncludingHidden: [ChainModel.Id: ChainModel]
    let visibility: AssetVisibility?

    init(
        priceResult: Result<[ChainAssetId: PriceData], Error>? = nil,
        balances: [ChainAssetId: Result<AssetBalance, Error>] = [:],
        allChains: [ChainModel.Id: ChainModel] = [:],
        externalBalances: Result<[ChainAssetId: [ExternalAssetBalance]], Error>? = nil,
        chainsIncludingHidden: [ChainModel.Id: ChainModel] = [:],
        visibility: AssetVisibility? = nil
    ) {
        self.priceResult = priceResult
        self.balances = balances
        self.allChains = allChains
        self.externalBalances = externalBalances
        self.chainsIncludingHidden = chainsIncludingHidden
        self.visibility = visibility
    }

    init(
        model: AssetListBuilderResult.Model,
        chainsIncludingHidden: [ChainModel.Id: ChainModel] = [:],
        visibility: AssetVisibility? = nil
    ) {
        priceResult = model.priceResult
        allChains = model.allChains
        balances = model.balances
        externalBalances = model.externalBalanceResult
        self.chainsIncludingHidden = chainsIncludingHidden
        self.visibility = visibility
    }
}

extension AssetListModel {
    func chains(includingHidden: Bool) -> [ChainModel.Id: ChainModel] {
        includingHidden ? chainsIncludingHidden : allChains
    }
}
