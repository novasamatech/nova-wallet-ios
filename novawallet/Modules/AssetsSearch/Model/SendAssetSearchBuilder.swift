import BigInt

final class SendAssetSearchBuilder: AssetSearchBuilder {
    override func assetListState(from model: AssetListModel) -> AssetListState {
        let balanceResults = model.balances.reduce(into: [ChainAssetId: Result<BigUInt, Error>]()) {
            switch $1.value {
            case let .success(balance):
                $0[$1.key] = .success(balance.transferable)
            case let .failure(error):
                $0[$1.key] = .failure(error)
            }
        }

        return AssetListState(
            priceResult: model.priceResult,
            balanceResults: balanceResults,
            allChains: model.allChains,
            externalBalances: nil
        )
    }
}
