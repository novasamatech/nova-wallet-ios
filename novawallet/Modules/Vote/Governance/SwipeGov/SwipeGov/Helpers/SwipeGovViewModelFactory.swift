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

        let languages = genericParams.locale.rLanguages

        let titleText = R.string(
            preferredLanguages: languages
        ).localizable.commonCountedReferenda(filteredReferendums.count)

        return .swipeGov(
            SwipeGovBannerViewModel(
                title: R.string(preferredLanguages: languages).localizable.commonSwipeGov(),
                description: R.string(preferredLanguages: languages).localizable.swipeGovBannerMessage(),
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
                title: R.string(preferredLanguages: languages).localizable.votingListWidgetTitleEmpty()
            )
        } else {
            VotingListWidgetViewModel.votings(
                value: "\(votingList.count)",
                title: R.string(preferredLanguages: languages).localizable.votingListWidgetTitle()
            )
        }
    }

    func createReferendumsCounterViewModel(
        availableToVoteCount: Int,
        locale: Locale
    ) -> String? {
        if availableToVoteCount > 0 {
            R.string(preferredLanguages: locale.rLanguages).localizable.swipeGovReferendaCounter(availableToVoteCount)
        } else {
            R.string(preferredLanguages: locale.rLanguages).localizable.swipeGovReferendaCounterEmpty()
        }
    }
}
