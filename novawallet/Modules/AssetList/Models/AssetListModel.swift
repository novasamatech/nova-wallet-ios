import BigInt

typealias AssetListModelObservable = Observable<NotEqualWrapper<AssetListModel>>

struct AssetListModel {
    let priceResult: Result<[ChainAssetId: PriceData], Error>?
    let allChains: [ChainModel.Id: ChainModel]
    let balances: [ChainAssetId: Result<AssetBalance, Error>]
    let externalBalances: Result<[ChainAssetId: [ExternalAssetBalance]], Error>?

    init(
        priceResult: Result<[ChainAssetId: PriceData], Error>? = nil,
        balances: [ChainAssetId: Result<AssetBalance, Error>] = [:],
        allChains: [ChainModel.Id: ChainModel] = [:],
        externalBalances: Result<[ChainAssetId: [ExternalAssetBalance]], Error>? = nil
    ) {
        self.priceResult = priceResult
        self.balances = balances
        self.allChains = allChains
        self.externalBalances = externalBalances
    }

    init(model: AssetListBuilderResult.Model) {
        priceResult = model.priceResult
        allChains = model.allChains
        balances = model.balances
        externalBalances = model.externalBalanceResult
    }
}
