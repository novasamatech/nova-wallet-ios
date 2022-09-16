import Foundation

struct AssetBalanceChanged: EventProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let changes: Data?
    let block: Data?

    func accept(visitor: EventVisitorProtocol) {
        visitor.processAssetBalanceChanged(event: self)
    }
}
