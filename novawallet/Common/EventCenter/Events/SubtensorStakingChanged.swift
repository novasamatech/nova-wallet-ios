import Foundation

struct SubtensorStakingChanged: EventProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSubtensorStakingChanged(event: self)
    }
}
