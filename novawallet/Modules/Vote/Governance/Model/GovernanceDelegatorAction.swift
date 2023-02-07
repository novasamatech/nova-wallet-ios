import Foundation
import BigInt

struct GovernanceDelegatorAction: Hashable {
    enum ActionType: Hashable {
        case undelegate
        case delegate(Delegate)
    }

    struct Delegate: Hashable {
        let balance: BigUInt
        let conviction: ConvictionVoting.Conviction
    }

    let delegateId: AccountId
    let trackId: TrackIdLocal
    let type: ActionType
}
