import Foundation

struct ChainAccountId: Equatable, Hashable {
    let chainId: ChainModel.Id
    let accountId: AccountId
}
