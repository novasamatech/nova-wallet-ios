import Foundation

struct SubtensorChanged: EventProtocol {
    let chainAssetId: ChainAssetId
    let accountId: AccountId

    func accept(visitor: EventVisitorProtocol) {
        visitor.processSubtensorChanged(event: self)
    }
}
