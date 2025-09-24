import Foundation

protocol SwipeGovViewModelFactoryProtocol {
    func createSwipeGovReferendumsSection(
        with referendumsState: ReferendumsState,
        eligibleReferendums: Set<ReferendumIdLocal>,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsSection?

    func createVotingListViewModel(
        from votingList: [VotingBasketItemLocal],
        locale: Locale
    ) -> VotingListWidgetViewModel

    func createReferendumsCounterViewModel(
        availableToVoteCount: Int,
        locale: Locale
    ) -> String?
}

struct SwipeGovViewModelFactory: SwipeGovViewModelFactoryProtocol {
    func createSwipeGovReferendumsSection(
        with referendumsState: ReferendumsState,
        eligibleReferendums: Set<ReferendumIdLocal>,
        genericParams: ViewModelFactoryGenericParams
    ) -> ReferendumsSection? {
        let filteredReferendums = ReferendumFilter.EligibleForSwipeGov(
            referendums: referendumsState.referendums,
            accountVotes: referendumsState.voting?.value?.votes,
            elegibleReferendums: eligibleReferendums
        ).callAsFunction()

        guard !filteredReferendums.isEmpty else {
            return nil
        }

        let titleText = R.string.localizable.commonCountedReferenda(
            filteredReferendums.count,
            preferredLanguages: genericParams.locale.rLanguages
        )

        return .swipeGov(
            SwipeGovBannerViewModel(
                title: R.string.localizable.commonSwipeGov(
                    preferredLanguages: genericParams.locale.rLanguages
                ),
                description: R.string.localizable.swipeGovBannerMessage(
                    preferredLanguages: genericParams.locale.rLanguages
                ),
                referendumCounterText: .wrapped(titleText, with: genericParams.privacyModeEnabled)
            )
        )
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
        availableToVoteCount: Int,
        locale: Locale
    ) -> String? {
        if availableToVoteCount > 0 {
            R.string.localizable.swipeGovReferendaCounter(
                availableToVoteCount,
                preferredLanguages: locale.rLanguages
            )
        } else {
            R.string.localizable.swipeGovReferendaCounterEmpty(
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
