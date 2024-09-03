import Foundation

protocol TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        using filter: TinderGovReferendumsFilter,
        locale: Locale
    ) -> ReferendumsSection?

    func createVoteCardViewModels(
        from referendums: [ReferendumLocal],
        onVote: @escaping (VoteResult, ReferendumIdLocal) -> Void,
        onBecomeTop: @escaping (ReferendumIdLocal) -> Void
    ) -> [VoteCardViewModel]

    func createVotingListViewModel(from votingList: [ReferendumIdLocal]) -> VotingListWidgetViewModel

    func createReferendumsCounterViewModel(
        currentReferendumId: ReferendumIdLocal,
        referendums: [ReferendumLocal]
    ) -> String?
}

struct TinderGovViewModelFactory {
    private let cardGradientFactory = TinderGovGradientFactory()
}

extension TinderGovViewModelFactory: TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        using filter: TinderGovReferendumsFilter,
        locale: Locale
    ) -> ReferendumsSection? {
        let tinderGovReferenda = filter()

        let section: ReferendumsSection? = {
            guard !tinderGovReferenda.isEmpty else {
                return nil
            }

            return .tinderGov(
                TinderGovBannerViewModel(
                    title: R.string.localizable.commonTinderGov(preferredLanguages: locale.rLanguages),
                    description: R.string.localizable.tinderGovBannerMessage(
                        preferredLanguages: locale.rLanguages
                    ),
                    referendumCounterText: R.string.localizable.commonCountedReferenda(
                        tinderGovReferenda.count,
                        preferredLanguages: locale.rLanguages
                    )
                )
            )
        }()

        return section
    }

    func createVoteCardViewModels(
        from referendums: [ReferendumLocal],
        onVote: @escaping (VoteResult, ReferendumIdLocal) -> Void,
        onBecomeTop: @escaping (ReferendumIdLocal) -> Void
    ) -> [VoteCardViewModel] {
        referendums.enumerated().map { index, referendum in
            let gradientModel = cardGradientFactory.createCardGratient(for: index)

            return VoteCardViewModel(
                referendum: referendum,
                gradient: gradientModel,
                onVote: onVote,
                onBecomeTop: onBecomeTop
            )
        }
    }

    func createVotingListViewModel(from votingList: [ReferendumIdLocal]) -> VotingListWidgetViewModel {
        if votingList.isEmpty {
            VotingListWidgetViewModel.empty(count: "0", title: "No votings")
        } else {
            VotingListWidgetViewModel.votings(count: "\(votingList.count)", title: "Voting list")
        }
    }

    func createReferendumsCounterViewModel(
        currentReferendumId: ReferendumIdLocal,
        referendums: [ReferendumLocal]
    ) -> String? {
        guard let currentIndex = referendums.firstIndex(where: { $0.index == currentReferendumId }) else {
            return nil
        }

        let currentNumber = referendums.count - currentIndex

        let counterString = "\(currentNumber) of \(referendums.count)"

        return counterString
    }
}
