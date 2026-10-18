import Foundation

struct SubtensorStakeChanged: EventProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSubtensorStakeChanged(event: self)
    }
}
