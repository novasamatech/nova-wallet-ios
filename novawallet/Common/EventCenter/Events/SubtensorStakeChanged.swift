import Foundation

struct SubtensorStakeChanged: EventProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId
    let netuids: Set<UInt16>

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSubtensorStakeChanged(event: self)
    }
}
