import Foundation

protocol SwipeGovViewModelFactoryProtocol {
    func createSwipeGovReferendumsSection(
        with referendumsState: ReferendumsState,
        locale: Locale
    ) -> ReferendumsSection?

    func createVotingListViewModel(
        from votingList: [VotingBasketItemLocal],
        locale: Locale
    ) -> VotingListWidgetViewModel

    func createReferendumsCounterViewModel(
        referendums: [ReferendumLocal],
        votingList: [VotingBasketItemLocal],
        locale: Locale
    ) -> String?
}

struct SwipeGovViewModelFactory: SwipeGovViewModelFactoryProtocol {
    func createSwipeGovReferendumsSection(
        with referendumsState: ReferendumsState,
        locale: Locale
    ) -> ReferendumsSection? {
        let filteredReferendums = ReferendumFilter.VoteAvailable(
            referendums: referendumsState.referendums,
            accountVotes: referendumsState.voting?.value?.votes
        ).callAsFunction()

        let section: ReferendumsSection? = {
            guard !referendumsState.referendums.isEmpty else {
                return nil
            }

            return .swipeGov(
                SwipeGovBannerViewModel(
                    title: R.string.localizable.commonSwipeGov(preferredLanguages: locale.rLanguages),
                    description: R.string.localizable.swipeGovBannerMessage(
                        preferredLanguages: locale.rLanguages
                    ),
                    referendumCounterText: R.string.localizable.commonCountedReferenda(
                        filteredReferendums.count,
                        preferredLanguages: locale.rLanguages
                    )
                )
            )
        }()

        return section
    }

    func createVotingListViewModel(
        from votingList: [VotingBasketItemLocal],
        locale: Locale
    ) -> VotingListWidgetViewModel {
        let languages = locale.rLanguages

        return if votingList.isEmpty {
            VotingListWidgetViewModel.empty(
                value: "0",
                title: R.string.localizable.votingListWidgetTitleEmpty(preferredLanguages: languages)
            )
        } else {
            VotingListWidgetViewModel.votings(
                value: "\(votingList.count)",
                title: R.string.localizable.votingListWidgetTitle(preferredLanguages: languages)
            )
        }
    }

    func createReferendumsCounterViewModel(
        referendums: [ReferendumLocal],
        votingList: [VotingBasketItemLocal],
        locale: Locale
    ) -> String? {
        guard !referendums.isEmpty else {
            return R.string.localizable.swipeGovReferendaCounterEmpty(
                preferredLanguages: locale.rLanguages
            )
        }

        let currentNumber = referendums.count - votingList.count

        let counterString = R.string.localizable.commonCounter(
            currentNumber,
            referendums.count,
            preferredLanguages: locale.rLanguages
        )

        return counterString
    }
}
