import Foundation

class SwipeGovVotingListViewModelFactory {
    let votesStringFactory: ReferendumDisplayStringFactoryProtocol

    init(votesStringFactory: ReferendumDisplayStringFactoryProtocol) {
        self.votesStringFactory = votesStringFactory
    }

    func createListViewModel(
        using votingListItems: [VotingBasketItemLocal],
        chain: ChainModel,
        locale: Locale
    ) -> SwipeGovVotingListViewModel {
        let cellModels = votingListItems.map { item in
            let votesString = votesStringFactory.createVotes(
                from: item.conviction.votes(for: item.amount),
                chain: chain,
                locale: locale
            )

            let voteTypeText = item.voteType.rawValue.capitalized.appending(":")

            let voteType: SwipeGovVotingListItemViewModel.VoteType = switch item.voteType {
            case .abstain: .abstain(text: voteTypeText)
            case .aye: .aye(text: voteTypeText)
            case .nay: .nay(text: voteTypeText)
            }

            return SwipeGovVotingListItemViewModel(
                referendumIndex: item.referendumId,
                indexText: "#\(item.referendumId)",
                titleText: "TITLE",
                voteType: voteType,
                votesCountText: votesString
            )
        }

        return SwipeGovVotingListViewModel(cellViewModels: cellModels)
    }
}
