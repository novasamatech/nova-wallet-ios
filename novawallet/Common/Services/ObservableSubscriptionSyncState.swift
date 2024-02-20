import Foundation
import SubstrateSdk

struct ObservableSubscriptionState: ObservableSubscriptionStateProtocol {
    typealias TChange = BatchSubscriptionHandler

    let blockHash: Data?

    init(blockHash: Data?) {
        self.blockHash = blockHash
    }

    init(change: TChange) {
        blockHash = change.blockHash
    }

    func merging(change: BatchSubscriptionHandler) -> ObservableSubscriptionState {
        .init(blockHash: change.blockHash)
    }
}
