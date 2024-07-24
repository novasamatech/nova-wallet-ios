import Foundation
import BigInt

enum ReferendumVoteAction: Hashable {
    case aye(ReferendumVoteActionModel)
    case nay(ReferendumVoteActionModel)
    case abstain(ReferendumVoteActionModel)

    func balance() -> BigUInt {
        switch self {
        case let .abstain(model),
             let .aye(model),
             let .nay(model):
            model.amount
        }
    }

    func conviction() -> ConvictionVoting.Conviction {
        switch self {
        case let .abstain(model),
             let .aye(model),
             let .nay(model):
            model.conviction
        }
    }
}

struct ReferendumVoteActionModel: Hashable {
    let amount: BigUInt
    let conviction: ConvictionVoting.Conviction
}
