import Foundation
import BigInt

enum ReferendumVoteAction: Hashable {
    case aye(ReferendumVoteActionModel)
    case nay(ReferendumVoteActionModel)
    case abstain(amount: BigUInt)

    func amount() -> BigUInt {
        switch self {
        case let .aye(model),
             let .nay(model):
            model.amount
        case let .abstain(amount):
            amount
        }
    }

    func conviction() -> ConvictionVoting.Conviction {
        switch self {
        case let .aye(model),
             let .nay(model):
            model.conviction
        case .abstain:
            .none
        }
    }
}

struct ReferendumVoteActionModel: Hashable {
    let amount: BigUInt
    let conviction: ConvictionVoting.Conviction
}
