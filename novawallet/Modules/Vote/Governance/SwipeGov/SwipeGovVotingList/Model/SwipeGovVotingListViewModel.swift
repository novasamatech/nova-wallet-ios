import Foundation

struct SwipeGovVotingListItemViewModel {
    enum VoteType {
        case aye(text: String)
        case nay(text: String)
        case abstain(text: String)

        func text() -> String {
            switch self {
            case let .aye(text), let .nay(text), let .abstain(text):
                return text
            }
        }
    }

    let referendumIndex: ReferendumIdLocal
    let indexText: String
    let titleText: String
    let voteType: VoteType
    let votesCountText: String?
}

struct SwipeGovVotingListViewModel {
    var cellViewModels: [SwipeGovVotingListItemViewModel]
}
