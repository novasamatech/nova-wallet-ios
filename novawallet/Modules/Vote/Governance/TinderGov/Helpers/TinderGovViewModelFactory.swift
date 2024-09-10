import Foundation

protocol TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        with referendums: [ReferendumLocal],
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

struct TinderGovViewModelFactory: TinderGovViewModelFactoryProtocol {
    func createTinderGovReferendumsSection(
        with referendums: [ReferendumLocal],
        locale: Locale
    ) -> ReferendumsSection? {
        let section: ReferendumsSection? = {
            guard !referendums.isEmpty else {
                return nil
            }

            return .tinderGov(
                TinderGovBannerViewModel(
                    title: R.string.localizable.commonTinderGov(preferredLanguages: locale.rLanguages),
                    description: R.string.localizable.tinderGovBannerMessage(
                        preferredLanguages: locale.rLanguages
                    ),
                    referendumCounterText: R.string.localizable.commonCountedReferenda(
                        referendums.count,
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
        let currentNumber = referendums.count - votingList.count

        let counterString = R.string.localizable.commonCounter(
            currentNumber,
            referendums.count,
            preferredLanguages: locale.rLanguages
        )

        return counterString
    }
}
