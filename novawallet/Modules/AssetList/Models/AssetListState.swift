import Foundation
import BigInt

struct AssetListState {
    let priceResult: Result<[ChainAssetId: PriceData], Error>?
    let balanceResults: [ChainAssetId: Result<BigUInt, Error>]
    let allChains: [ChainModel.Id: ChainModel]
    let externalBalances: Result<[ChainAssetId: [ExternalAssetBalance]], Error>?
    let balances: [ChainAssetId: Result<AssetBalance, Error>]

    init(
        priceResult: Result<[ChainAssetId: PriceData], Error>? = nil,
        balanceResults: [ChainAssetId: Result<BigUInt, Error>] = [:],
        allChains: [ChainModel.Id: ChainModel] = [:],
        externalBalances: Result<[ChainAssetId: [ExternalAssetBalance]], Error>? = nil,
        balances: [ChainAssetId: Result<AssetBalance, Error>] = [:]
    ) {
        self.priceResult = priceResult
        self.balanceResults = balanceResults
        self.allChains = allChains
        self.externalBalances = externalBalances
        self.balances = balances
    }

    init(model: AssetListBuilderResult.Model) {
        priceResult = model.priceResult
        balanceResults = model.balanceResults
        allChains = model.allChains
        externalBalances = model.externalBalanceResult
        balances = model.balances
    }

    func chainAsset(for chainAssetId: ChainAssetId) -> ChainAsset? {
        let chainId = chainAssetId.chainId
        let assetId = chainAssetId.assetId

        guard let chain = allChains[chainId],
              let asset = chain.assets.first(where: { $0.assetId == assetId }) else {
            return nil
        }

        return .init(chain: chain, asset: asset)
    }
}

typealias AssetListStateObservable = Observable<NotEqualWrapper<AssetListState>>
