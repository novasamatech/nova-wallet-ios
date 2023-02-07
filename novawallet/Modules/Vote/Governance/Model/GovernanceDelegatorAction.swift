import Foundation
import BigInt

struct GovernanceDelegatorAction {
    enum ActionType {
        case undelegate
        case delegate(Delegate)
    }

    struct Delegate {
        let balance: BigUInt
        let conviction: ConvictionVoting.Conviction
    }

    let delegateId: AccountId
    let trackId: TrackIdLocal
    let type: ActionType
}
