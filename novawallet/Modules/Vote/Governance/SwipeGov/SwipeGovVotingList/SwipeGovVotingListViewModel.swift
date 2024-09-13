import Foundation

struct SwipeGovVotingListItemViewModel {
    let referendumIndex: ReferendumIdLocal
    let indexText: String
    let titleText: String
    let voteTypeText: String
    let votesCountText: String
}

struct SwipeGovVotingListViewModel {
    var cellViewModels: [SwipeGovVotingListItemViewModel]
}
