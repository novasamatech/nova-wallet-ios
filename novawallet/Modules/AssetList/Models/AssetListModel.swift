import BigInt

typealias AssetListModelObservable = Observable<NotEqualWrapper<AssetListModel>>

struct AssetListModel {
    let priceResult: Result<[ChainAssetId: PriceData], Error>?
    let allChains: [ChainModel.Id: ChainModel]
    let balances: [ChainAssetId: Result<AssetBalance, Error>]

    init(
        priceResult: Result<[ChainAssetId: PriceData], Error>? = nil,
        balances: [ChainAssetId: Result<AssetBalance, Error>] = [:],
        allChains: [ChainModel.Id: ChainModel] = [:]
    ) {
        self.priceResult = priceResult
        self.balances = balances
        self.allChains = allChains
    }

    init(model: AssetListBuilderResult.Model) {
        priceResult = model.priceResult
        allChains = model.allChains
        balances = model.balances
    }

    func assetListState(balancePart: KeyPath<AssetBalance, BigUInt>) -> AssetListState {
        let balanceResults = balances.reduce(into: [ChainAssetId: Result<BigUInt, Error>]()) {
            switch $1.value {
            case let .success(balance):
                $0[$1.key] = .success(balance[keyPath: balancePart])
            case let .failure(error):
                $0[$1.key] = .failure(error)
            }
        }

        return AssetListState(
            priceResult: priceResult,
            balanceResults: balanceResults,
            allChains: allChains,
            externalBalances: nil
        )
    }
}
