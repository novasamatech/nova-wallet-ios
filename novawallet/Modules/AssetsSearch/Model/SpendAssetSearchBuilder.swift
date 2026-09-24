import BigInt

final class SpendAssetSearchBuilder: AssetSearchBuilder {
    override func assetListState(from model: AssetListModel) -> AssetListState {
        let chains = sourceChains(from: model)

        let chainAssets = chains.flatMap { _, chain in
            chain.assets.map { ChainAssetId(chainId: chain.chainId, assetId: $0.assetId) }
        }

        let balanceResults = chainAssets.reduce(into: [ChainAssetId: Result<BigUInt, Error>]()) {
            switch model.balances[$1] {
            case let .success(amount):
                $0[$1] = .success(amount.transferable)
            case let .failure(error):
                $0[$1] = .failure(error)
            case .none:
                $0[$1] = .success(0)
            }
        }

        return AssetListState(
            priceResult: model.priceResult,
            balanceResults: balanceResults,
            allChains: chains,
            externalBalances: nil,
            defaultRank: model.visibility?.defaults.rank ?? [:]
        )
    }
}
