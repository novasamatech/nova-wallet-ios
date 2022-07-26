import Foundation

struct AssetBalanceId: Equatable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
    let accountId: AccountId

    var chainAssetId: ChainAssetId {
        ChainAssetId(chainId: chainId, assetId: assetId)
    }
}
