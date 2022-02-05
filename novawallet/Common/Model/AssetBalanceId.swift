import Foundation

struct AssetBalanceId: Equatable {
    let chainId: ChainModel.Id
    let assetId: AssetModel.Id
    let accountId: AccountId
}
